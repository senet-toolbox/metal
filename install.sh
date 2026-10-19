#!/bin/sh
# Installs metal, the CLI for the Zig web toolbox.
#
#   curl -fsSL https://raw.githubusercontent.com/senet-toolbox/metal/main/install.sh | sh
#
# Environment:
#   METAL_VERSION      version to install, e.g. 1.2.0 (default: latest release)
#   METAL_INSTALL_DIR  where to put the binary (default: the directory of an
#                      existing writable `metal` on PATH, else ~/.local/bin)
#   METAL_REPO         GitHub repository to download from
#   METAL_NO_MODIFY_PATH  set to leave shell startup files alone. Otherwise,
#                      when ~/.local/bin is not on PATH, one line adding it is
#                      appended to your shell's startup file (once).
#
# No sudo: the default directory is your own. To install system-wide, run
#   curl -fsSL … | sudo METAL_INSTALL_DIR=/usr/local/bin sh
set -eu

REPO="${METAL_REPO:-senet-toolbox/metal}"
# For testing against a local mirror of the release assets.
DOWNLOAD_BASE="${METAL_DOWNLOAD_BASE:-}"

say() { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "'$1' is required but not installed"; }

need curl
need tar
need uname

case "$(uname -s)" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
    *) fail "unsupported OS: $(uname -s) (metal ships for macOS and Linux)" ;;
esac

case "$(uname -m)" in
    arm64 | aarch64) arch=arm64 ;;
    x86_64 | amd64) arch=x86_64 ;;
    *) fail "unsupported architecture: $(uname -m)" ;;
esac

# Rosetta reports x86_64 on an Apple Silicon Mac; prefer the native binary.
if [ "$os" = darwin ] && [ "$arch" = x86_64 ] &&
    [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then
    arch=arm64
fi

if [ -n "${METAL_VERSION:-}" ]; then
    version="${METAL_VERSION#v}"
elif [ -n "$DOWNLOAD_BASE" ]; then
    fail "METAL_VERSION is required with METAL_DOWNLOAD_BASE"
else
    # /releases/latest redirects to /releases/tag/v<version>; reading the
    # redirect avoids the API and its rate limit.
    latest_url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest") ||
        fail "could not reach github.com/$REPO"
    version="${latest_url##*/v}"
    case "$version" in
        "" | */*) fail "could not determine the latest release of $REPO" ;;
    esac
fi

name="metal-$version-$os-$arch"
base="${DOWNLOAD_BASE:-https://github.com/$REPO/releases/download/v$version}"

tmp=$(mktemp -d 2>/dev/null || mktemp -d -t metal)
trap 'rm -rf "$tmp"' EXIT INT TERM

say "Downloading metal $version for $os-$arch..."
curl -fsSL -o "$tmp/$name.tar.gz" "$base/$name.tar.gz" ||
    fail "download failed: $base/$name.tar.gz"
curl -fsSL -o "$tmp/checksums.txt" "$base/checksums.txt" ||
    fail "download failed: $base/checksums.txt"

expected=$(awk -v f="$name.tar.gz" '$2 == f { print $1 }' "$tmp/checksums.txt")
[ -n "$expected" ] || fail "no checksum for $name.tar.gz in checksums.txt"
if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$tmp/$name.tar.gz" | awk '{ print $1 }')
else
    actual=$(shasum -a 256 "$tmp/$name.tar.gz" | awk '{ print $1 }')
fi
[ "$expected" = "$actual" ] || fail "checksum mismatch for $name.tar.gz (expected $expected, got $actual)"

tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
[ -f "$tmp/$name/bin/metal" ] || fail "archive did not contain $name/bin/metal"

# Upgrade in place when an existing metal is on PATH and writable, so a new
# copy does not end up shadowed by the old one.
chosen_dir=
if [ -z "${METAL_INSTALL_DIR:-}" ]; then
    existing=$(command -v metal 2>/dev/null || true)
    if [ -n "$existing" ] && [ -w "$(dirname "$existing")" ]; then
        METAL_INSTALL_DIR=$(dirname "$existing")
    else
        METAL_INSTALL_DIR="$HOME/.local/bin"
        chosen_dir=1
    fi
fi

mkdir -p "$METAL_INSTALL_DIR" || fail "cannot create $METAL_INSTALL_DIR"
[ -w "$METAL_INSTALL_DIR" ] || fail "$METAL_INSTALL_DIR is not writable; set METAL_INSTALL_DIR or rerun with sudo"

# Write beside the target, then rename: atomic, and safe while metal itself
# is running (`metal upgrade`).
cp "$tmp/$name/bin/metal" "$METAL_INSTALL_DIR/.metal.new"
chmod 755 "$METAL_INSTALL_DIR/.metal.new"
mv -f "$METAL_INSTALL_DIR/.metal.new" "$METAL_INSTALL_DIR/metal"

say "Installed metal $version to $METAL_INSTALL_DIR/metal"

# The startup file the user's login shell reads, and the line that puts
# $1 on PATH in it.
shell_name=$(basename "${SHELL:-sh}")
profile_for_shell() {
    case "$shell_name" in
        zsh) printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc" ;;
        bash)
            if [ "$os" = darwin ]; then
                # Terminal.app starts login shells, which read only the first
                # of these that exists; creating .bash_profile next to an
                # existing .profile would stop .profile being read.
                for f in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
                    if [ -f "$f" ]; then printf '%s\n' "$f"; return; fi
                done
                printf '%s\n' "$HOME/.bash_profile"
            else
                printf '%s\n' "$HOME/.bashrc"
            fi
            ;;
        fish) printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish" ;;
        *) printf '%s\n' "$HOME/.profile" ;;
    esac
}
path_line() {
    case "$shell_name" in
        fish) printf 'set -gx PATH "%s" $PATH\n' "$1" ;;
        *) printf 'export PATH="%s:$PATH"\n' "$1" ;;
    esac
}

metal_cmd=metal
found=$(command -v metal 2>/dev/null || true)
case ":$PATH:" in
    *":$METAL_INSTALL_DIR:"*)
        if [ -n "$found" ] && [ "$found" != "$METAL_INSTALL_DIR/metal" ]; then
            say ""
            say "note: '$found' comes first on your PATH and will run instead."
            say "      Remove it, or reorder PATH."
        fi
        ;;
    *)
        # An upgrade replaced the binary the user just ran; PATH is theirs.
        [ -n "${METAL_UPGRADE:-}" ] && exit 0

        profile=$(profile_for_shell)
        # $HOME-relative, so the line still works in dotfiles synced to
        # another machine.
        path_dir=$METAL_INSTALL_DIR
        case "$path_dir" in "$HOME"/*) path_dir="\$HOME${path_dir#"$HOME"}" ;; esac
        line=$(path_line "$path_dir")
        marker="# added by the metal installer"
        say ""
        # Only for the directory chosen here: one the user named is theirs.
        if [ -n "$chosen_dir" ] && [ -z "${METAL_NO_MODIFY_PATH:-}" ]; then
            if grep -qsF "$marker" "$profile"; then
                say "$METAL_INSTALL_DIR is already added to PATH in $profile."
            elif mkdir -p "$(dirname "$profile")" 2>/dev/null &&
                printf '\n%s\n%s\n' "$marker" "$line" >>"$profile" 2>/dev/null; then
                say "Added $METAL_INSTALL_DIR to PATH in $profile."
            else
                say "Could not write $profile. Add this line to your shell's startup file:"
                say "  $line"
            fi
            say "New terminals will find metal. For this one, run:"
            say "  $line"
        else
            say "$METAL_INSTALL_DIR is not on your PATH. Add this line to $profile:"
            say "  $line"
        fi
        # This terminal cannot see the change yet, so spell out the path.
        metal_cmd="$METAL_INSTALL_DIR/metal"
        case "$metal_cmd" in "$HOME"/*) metal_cmd="~${metal_cmd#"$HOME"}" ;; esac
        ;;
esac

# `metal upgrade` sets METAL_UPGRADE: the user already has metal running.
[ -n "${METAL_UPGRADE:-}" ] && exit 0

if ! command -v zig >/dev/null 2>&1; then
    say ""
    say "metal needs Zig 0.16.0: https://ziglang.org/download/"
fi

say ""
say "Get started:  $metal_cmd vapor create my-app && cd my-app && $metal_cmd vapor run"

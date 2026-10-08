# metal

A CLI for the Zig web toolbox: scaffolds apps, runs a dev server with live
reload, builds releases, and adds packages.

Three frameworks share one command surface:

| framework | what it is |
| --- | --- |
| `vapor` | Zig → WebAssembly UI framework (frontend) |
| `reverb` | HTTP server (backend) |
| `canopy` | backend |

For `vapor`, `metal run` starts a dev server and a file watcher. For the
backend frameworks it only watches and rebuilds — your app is its own server.

## Requirements

Zig 0.16. Run `metal doctor` to check the rest; `wasm-opt` and `brotli` are
needed only for `metal vapor release`.

## Install

```bash
curl -sSL https://raw.githubusercontent.com/senet-toolbox/metal/main/install.sh | bash
```

`metal upgrade` re-runs that script.

## Quick start

```bash
metal vapor create my-app
cd my-app
metal vapor run --open
```

`create` writes the project, then fetches vapor into it with
`zig fetch --save`, pinned to the vapor version this metal release's templates
are written against (`vapor_ref` in `src/main.zig`). The JS runtime comes from
that same vapor dependency — the app's build installs it next to the wasm as
`zig-out/bin/bundle.min.js` — so the two can never come from different
versions.

Developing vapor itself? Point a new app at your checkout instead:

```bash
metal vapor create my-app --vapor-path ../vapor
```

## Commands

```
metal <framework> <command> [options]
```

| command | what it does |
| --- | --- |
| `create <name>` | scaffold a new project into `<name>/` |
| `run` | build, serve, watch, live-reload |
| `build` | build once |
| `release` | build → wasm-opt → brotli |
| `add <package>` | `zig fetch --save` a known package |
| `gen <type> <Name>` | generate a source file from a template |
| `doctor` | check the toolchain |
| `clean` | remove `zig-out/`, `.zig-cache/` |
| `upgrade` | update metal itself |
| `version`, `help` | |

Both are also valid without a framework: `metal doctor`, `metal clean`,
`metal upgrade`, `metal version`, `metal help`.

Packages `add` knows: `vapor`, `vaporize`, `auth`.

Gen types: `page`, `component`, `card`, `button`, `template`, `fetch`,
`tutorial`, `crud`, `crudfull`, `database`. Output goes to a directory chosen
per type (`page` → `src/routes/`, components → `src/components/`) unless
`--output` says otherwise.

### Options

`run` / `build` / `release`:

| flag | effect |
| --- | --- |
| `-p, --port <n>` | port to serve on (default 5173) |
| `--host <addr>` | interface to bind (default `127.0.0.1`) |
| `--open` | open a browser on start |
| `-r, --release` | release build |
| `-g, --generate` | run the static generator |
| `-s, --static` | serve the prerendered `release/` output |
| `--ssg` | static site generation |

`gen`:

| flag | effect |
| --- | --- |
| `-o, --output <path>` | write here instead of the default directory |
| `-f, --force` | overwrite an existing file |
| `--dry-run` | print what would be written |
| `-q, --quiet` | suppress progress output |
| `-t, --template <name>` | pick a named template |

An explicit `--port` that is already in use is an error. A default port that is
in use falls back to the next free port and says so.

### Binding to the network

The dev server serves files from the project directory and has no
authentication, so it binds `127.0.0.1` by default. To reach it from another
device — a phone on the same wifi, say — opt in:

```bash
metal vapor run --host 0.0.0.0
```

Do that only on networks you trust.

## Configuration

Optional `metal.zon` in the project root:

```zig
.{
    .port = 5173,
    .host = "127.0.0.1",
}
```

Precedence is flag > `metal.zon` > default.

## Exit codes

| code | meaning |
| --- | --- |
| `0` | success |
| `1` | the command ran and failed |
| `2` | the invocation was wrong (unknown command, missing argument) |
| `130` | interrupted (Ctrl-C) |

So `metal vapor build && ./deploy.sh` does the right thing, and `metal doctor`
can gate a setup script.

## Development

```bash
zig build          # also runs `check`
zig build test     # unit tests, root is src/tests.zig
zig build check    # type-check every file, including code nothing calls
zig fmt --check build.zig src
```

`zig build check` exists because Zig analyses declarations lazily: a function
nothing calls is parsed but never type-checked, so `zig build` can pass while
whole functions are broken. `src/check.zig` references every public
declaration to force the analysis, and `build.zig` fails the step if a file
under `src/` is missing from that list.

`-Dcheck-linux=true` adds an x86_64-linux check target. It passes: loom has
an epoll backend and the file watcher uses inotify on Linux.

Release binaries cross-compile from one Mac for all four targets:

```bash
for t in aarch64-macos x86_64-macos x86_64-linux-musl aarch64-linux-musl; do
  zig build -Dtarget=$t -Doptimize=ReleaseSafe --prefix out/$t
done
```

Cross-targeting macOS needs the SDK; `build.zig` asks `xcrun --show-sdk-path`
for it, so this works from macOS but not from a Linux host.

Verifying the scaffold end to end, from nothing:

```bash
cd /tmp && rm -rf t && mkdir t && cd t
metal vapor create fresh && cd fresh && zig build && zig build -Dgenerate=true
```

## Releasing

```bash
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos.13.0.0 install
# stage zig-out/bin/metal into metal-<version>-darwin-arm64/
tar -czf metal-<version>-darwin-arm64.tar.gz metal-<version>-darwin-arm64/
# update install.sh, commit, then:
git tag v<version> && git push --tags origin main
# upload the tarball to the GitHub release assets
```

The version lives only in `build.zig.zon`; `build.zig` passes it to the
binary. Before releasing, tag vapor and set `vapor_ref` in `src/main.zig` to that
tag — `"main"` is a development placeholder.

## License

MIT. See [LICENSE](LICENSE).

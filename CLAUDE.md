# metal — working notes

This file exists so a fresh session starts informed instead of re-deriving.
**Start with "Current task" below**; the rest is durable background.

## Current task (2026-11-02): release metal 2.2.0, new apps on vapor 3.5.2

`vapor_ref` is `v3.5.2` and `build.zig.zon` is **2.2.0**, committed locally
and not tagged: ask before pushing the `v2.2.0` tag. 3.5.2 is the version
the user named; vapor also has v3.6.x and v3.7.x tags.

Every 3.1.x vapor crashes `zig build -Dgenerate=true` on x86_64 Linux
(`index out of bounds: index 170, len 5` in css/values.zig, an unset
`position_type`; macOS and aarch64 happen to read zeros). vapor `0f8258a`
fixed it, first in v3.2.1. That is why CI's "Default create uses the pinned
vapor release" step failed on 2.1.0, which pins v3.1.0. Check a vapor bump
on x86_64 Linux, not only macOS: Docker `--platform linux/amd64` with a
cross-built `-Dtarget=x86_64-linux-musl` metal works.

Policy (agreed with the user): metal **pins** a tested vapor tag and moves
it in a metal release whenever vapor releases. It never floats on "latest".
release.yml already refuses `"main"`. Patch releases of vapor make patch
releases of metal, and minor releases make minor ones.

Verified on 3.5.2 (2026-11-02): `metal vapor create` fetches
`vapor-3.5.2-VGoNddqMFABReKGR2dzuF7GjK3Dq_Ip2WzBWfl_k8NEd`, then `zig build`
and `zig build -Dgenerate=true` pass on macOS and x86_64 Linux. Every
`metal vapor gen` kind compiles when referenced (CI's Showcase page), and
`/`, `/about` and `/showcase` render in headless Chrome under `metal vapor
run`.

4. Worth adding: a `metal vapor upgrade` (or similar) that moves an
   *existing* app to metal's `vapor_ref` (`zig fetch --save=vapor
   git+https://github.com/senet-toolbox/vapor#<ref>`, then point at
   `zig build migrate` for majors). Discuss with the user first.

### Done (2026-11-02): metal 2.1.0, `metal reverb run` starts the server

Before 2.1.0 the reverb/canopy branch of `run` only rebuilt (`run_after_build
= null`) yet printed "Server Ready :8080", so nothing listened and
assembler-chat's playground failed against it. Now the watcher starts the one
executable in `zig-out/bin` (or metal.zon `.run_command`) after each good
build and kills it before the next; Ctrl-C forwards SIGTERM to it. Checked on
assembler-backend: up in 2s, new PID after an edit, gone after SIGTERM.
vapor_ref was left at v3.1.0 in 2.1.0; 2.2.0 moves it.

### Done (2026-10-17): metal 2.0.0

New apps on vapor 3.1.0 (templates migrated, `metal gen` strings checked).
`metal upgrade` replaces the running binary wherever it lives. It verifies
checksums, refuses Homebrew installs, and handles read-only directories.
It was tested against a local mirror (`METAL_DOWNLOAD_BASE=file://…`,
`METAL_INSTALL_SCRIPT=file://…/install.sh`). release.yml now uploads into
an existing release; the hand-made v1.2.0 release had no binaries. 2.0.0
is tagged and pushed. The user's metal is now `~/.local/bin/metal`.

Background for template work: `metal gen` templates are Zig inside
multiline strings in `src/file_contents.zig`, which `zig build migrate`
skips. Check them by generating each into a fresh app and compiling. Zig
analyses lazily, so a generated page must be referenced or its errors stay
hidden.

### Later: Homebrew tap

A `senet-toolbox/homebrew-tap` repo with `Formula/metal.rb` pointing at the
release tarballs and their sha256 (per OS/arch via `on_macos`/`on_linux` +
`Hardware::CPU.arm?`). `brew install senet-toolbox/tap/metal`. The release
workflow can bump it with a token that can push to the tap. homebrew-core
needs a notable project; start with the tap.

### Things the metal dev server must keep doing (verified in vapor 3.x apps)

- serve `/bundle.min.js` (and `/browser.min.js`) from `zig-out/bin/`; the
  scaffold's `template.html` loads `<script type="module" src="/bundle.min.js">`.
  The April-2026 installed metal served `app.html` for that path, which is why
  3.x sites failed under it.
- `metal vapor release -g` = ReleaseSmall + wasm-opt + brotli, regenerating
  `release/` from `template.html` (works; used on senet-website 2026-10-16).

## The repos and how they relate

All siblings under `~/Desktop/Zig/`:

| repo | remote | what it is |
| --- | --- | --- |
| `vapor` | `senet-toolbox/vapor` | Zig → WebAssembly UI framework. **v3.1.1** (tag pushed 2026-10-19) |
| `metal` | `senet-toolbox/metal` (`metal-cli` redirects here) | CLI: scaffolds apps, runs the dev server, adds packages; releases + install.sh live here |
| `opaque-ui` | `senet-toolbox/opaque` | component library, on vapor 3.1.1; `zig build check` compiles every component |
| `vapor-ui` | `senet-toolbox/vapor-ui` | the opaque-ui showcase site; `zig build test-ui` runs headless-Chrome interaction tests |
| `vaporize` | `senet-toolbox/vaporize` | utility layer (markdown, syntax highlighting), on vapor 3.1.1 |
| `senet-website` | `senet-toolbox/senet` (old `vic-Rokx/tether-website` URL redirects) | the docs site, on vapor 3.1.1 and vapor's own JS runtime |
| `reverb` | `senet-toolbox/reverb` | server framework metal's dev server uses (pinned by git+https commit) |

`senet-website/documents/*.md` is the public documentation for vapor; its
drift checker `senet-website/scripts/check-docs-api.py` resolves every
`Vapor.*` symbol in the docs against vapor's source (3.x files). Run it after
any vapor API change.

The vapor JS runtime lives in vapor (`js/src` → `js/dist/bundle.min.js`,
named lazy path `runtime`; `runtime-browser` for `browser.min.js`). Apps
install both next to the wasm from their build.zig.

## Conventions established in the vapor work

Worth keeping, because they caught real bugs:

**`unreachable` is undefined behaviour in the mode we ship.** Debug and
ReleaseSafe panic; **ReleaseFast and ReleaseSmall let the optimizer assume the
branch is unreachable**. `catch unreachable` on a failed allocation therefore
does something arbitrary rather than crashing cleanly. vapor went from 219 such
sites to zero. Prefer, in order:

1. degradation the signature already expresses — `?T` → `return null`,
   `[]const u8` → return the input untransformed, `void` → skip and log
2. `@panic("message")` when the signature cannot express failure — still
   aborts, but identically in every optimize mode, and it says why

**`catch {}` is often correct** — vapor has ~768 and they are almost all style
writes where skipping a declaration is the right answer. Do not sweep them.

**Mutation-test every fix.** Revert the fix, confirm the new test fails with the
original symptom, restore. This keeps catching tests that pass for the wrong
reason.

**For mechanical refactors, byte-identical output beats unit tests.** vapor's
~180-site conversion was verified by regenerating `senet-website`'s
`release/index.html` and `style.css` and diffing.

**Zig analyses declarations lazily**, so unreferenced code is parsed but never
type-checked. vapor has `src/check.zig` + a `check` step; opaque-ui and
vapor-ui now have `zig build check` too. metal has no equivalent and may want
one, especially for the gen templates.

**Check Linux explicitly.** macOS links libc implicitly and defaults PIC
differently, so a Linux-only build failure is invisible locally.

**zsh, not bash**: don't pipe a command into `| tail` and then trust `$?`;
use `${=VAR}` for word-splitting.

## State of metal

Builds clean on Zig 0.16. Error handling is genuinely good — **267 `try` against
6 `catch unreachable`**. ~7,900 lines of real source
(`find src -name '*.zig' -not -path '*/templates/*'`).

### Package URLs and scaffolding (first sessions)

- `packageUrl()` returns `git+https://…` URLs; vapor resolves to
  `senet-toolbox/vapor` at `vapor_ref`.
- `zigFetchSave()` shells out to `zig fetch --save=<name> <url>`, so Zig resolves
  the commit, computes the hash and writes the `.url`/`.hash` pair itself.
- `create` fetches vapor into the new project after scaffolding;
  `src/templates/build.zig.zon` does not pre-declare vapor.
- **Gotcha:** `zig fetch --save` overwrites an existing dependency **keeping its
  field name**. A pre-existing `.path` entry becomes a `.path` holding a URL,
  and the build then tries to open the URL as a file path. This is why the
  template must not pre-declare vapor.
- `create` rewrites two placeholders in the template `build.zig.zon`:
  `.name = .metal_project_name,` and `.fingerprint = 0x0000000000000000,`.
  The fingerprint's high 32 bits must be CRC-32 of the name; the name must be a
  bare identifier (`packageNameFromDir` folds anything else to `_`, prefixing
  `app_` for a leading digit, keyword or empty result).
- The exe in `templates/build.zig` is deliberately **still named `vapor`** — the
  dev server and `template.html` hardcode `zig-out/bin/vapor.wasm`.
- `zig-pkg/` is where Zig 0.16 materialises fetched dependencies per build
  root; it regenerates on every build. It's in `.gitignore`.

### Session 2026-10-08 (launch prep)

- `vapor_ref` in `src/main.zig` pins new apps; release.yml refuses `"main"`.
- `metal vapor create <name> --vapor-path <dir>` for local vapor work.
- `gen` rewritten for vapor 2: page, component, card, button, fetch (needs
  the 3.x pass above).
- Linux works (Docker-verified), CI checks it; the scaffold generator needs
  `link_libc` on Linux.
- CI (`ci.yml`), release (`release.yml`), `install.sh` (no sudo,
  checksum-verified, macOS+Linux, arm64+x86_64). Release v1.2.0 published
  2026-10-08.

### Known issues remaining

1. Backend gen templates (`crud`, `crudfull`, `database`) still
   `@import("tether")` — reverb's old name; not updated or tested.
2. `metal add auth` points at `tether-labs/auth`, which does not exist.

## Testing helpers

- **Headless Chrome over CDP, no npm**: Node ≥ 22 has global `fetch` and
  `WebSocket`. `../vapor-ui/tests/run.mjs` is a complete example: a static
  server with SPA fallback to `template.html`, real pointer/keyboard input via
  `Input.dispatch*`, waits for `data-vapor-ready` on `<html>`, and fails on
  uncaught exceptions or vapor `[ERROR]`/`[WARN]` console lines. Copy its
  `launch()`/`makePage()` for a "generated app actually works" check.
- Smoke tests miss hover bugs unless the mouse moves
  (`Input.dispatchMouseEvent` sweeps) and responses are slow.
- Alpine container with Zig 0.16 for Linux e2e.

## Verifying changes

```bash
# metal
zig build
zig build test           # root is src/tests.zig

# the scaffold actually works, from nothing
cd /tmp && rm -rf t && mkdir t && cd t
<path>/metal vapor create fresh && cd fresh && zig build && zig build -Dgenerate=true

# vapor (sibling), the full CI sequence
cd ../vapor
zig build check          # wasm32-wasi, host, x86_64-linux
zig build test
zig build browser-test   # 28 tests; also -Dbrowser-optimize=ReleaseSmall, -Dbrowser-static=true

# docs have not drifted from the vapor API
cd ../senet-website && python3 scripts/check-docs-api.py --vapor ../vapor
```

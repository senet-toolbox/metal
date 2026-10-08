# metal-cli — working notes

Handoff from a long session spent hardening `vapor` (the sibling UI framework).
This file exists so a fresh session starts informed instead of re-deriving.

## The repos and how they relate

All siblings under `~/Desktop/Zig/`:

| repo | remote | what it is |
| --- | --- | --- |
| `vapor` | `senet-toolbox/vapor` | Zig → WebAssembly UI framework. **v2.0.1.** |
| `metal-cli` | *(this)* | CLI: scaffolds apps, runs the dev server, adds packages |
| `senet-website` | `vic-Rokx/tether-website` | the docs site; vapor's only production consumer |
| `vaporize` | `tether-labs/vaporize` | utility layer, generates content from markdown |
| `opaque-ui` | `senet-toolbox/opaque` | component library |

`senet-website/documents/*.md` is the public documentation for vapor. It has a
drift checker at `senet-website/scripts/check-docs-api.py` that resolves every
`Vapor.*` symbol in the docs against the library source. Run it after any vapor
API change.

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
original symptom, restore. This caught two cases where a test passed for the
wrong reason.

**For mechanical refactors, byte-identical output beats unit tests.** vapor's
~180-site conversion was verified by regenerating `senet-website`'s
`release/index.html` and `style.css` and diffing. That exercises the SSR path,
the style compiler and the config layer end to end.

**Zig analyses declarations lazily**, so unreferenced code is parsed but never
type-checked. vapor has `src/check.zig` + a `check` build step that references
every public declaration to force full analysis; it surfaced 68 latent compile
errors across 22 modules. metal-cli has no equivalent and may want one.

**Check Linux explicitly.** macOS links libc implicitly and defaults PIC
differently, so a Linux-only build failure is invisible locally. vapor's `check`
step runs wasm32-wasi, the host, *and* x86_64-linux for that reason.

## State of metal-cli

Builds clean on Zig 0.16. Error handling is genuinely good — **267 `try` against
6 `catch unreachable`**, so it was written with propagation in mind. ~7,900 lines
of real source (`find src -name '*.zig' -not -path '*/templates/*'`).

### Changed in the first session (package URLs)

`metal add <pkg>` and `metal vapor create` both pointed at stale, wrong-org
packages. Now:

- `packageUrl()` returns `git+https://…` URLs; vapor resolves to
  `senet-toolbox/vapor` (it was pointing at `tether-labs/vapor` **v1.1.8**)
- `zigFetchSave()` shells out to `zig fetch --save=<name> <url>`, so Zig resolves
  the commit, computes the hash and writes the `.url`/`.hash` pair itself. The
  previous hand-rolled `callZigFetch` + `addDependencyToZon` pinned a version
  that went stale on every vapor release.
- `create` fetches vapor into the new project after scaffolding
- `src/templates/build.zig.zon` no longer pre-declares vapor — see the gotcha
  below
- deleted `src/templates/zig-pkg/` (1.5 MB of vendored **vapor 1.3.0**, still
  containing `Static.zig`, `NewComponent.zig`, `typesnew.zig`, `PureTree.zig`,
  `Hooks.zig` — all removed in 2.0)
- `src/templates/src/main.zig` used the pre-2.0 `Shadow` shape
  (`.{ .top = …, .left = … }`); now `Vapor.Types.NewShadow.init().drop(…)`

**Gotcha worth remembering:** `zig fetch --save` overwrites an existing
dependency **keeping its field name**. A pre-existing `.path` entry becomes a
`.path` holding a URL, and the build then tries to open the URL as a file path.
This is why the template must not pre-declare vapor.

Verified clean-room: `metal vapor create fresh` → `zig build` → `zig build
-Dgenerate=true` → produces `release/index.html`, with no local vapor checkout.

### Fixed in the follow-up session (2026-08-14)

**1 — package identity.** `create` no longer copies `build.zig.zon` verbatim.
The template carries two placeholders, `.name = .metal_project_name,` and
`.fingerprint = 0x0000000000000000,`, and `renderTemplate` in `src/main.zig`
rewrites both per project; every other template is still copied byte for byte.
Confirmed empirically against Zig 0.16, because none of this is in `std`:

- the fingerprint's **high 32 bits must be CRC-32 of the name** — Zig validates
  it and errors with `invalid fingerprint: …; if this is a new or forked
  package, use this value: …`. The low 32 bits are a random id, not 0 or
  0xffffffff.
- the name **must be a bare identifier**. `.name = .@"my-app"` is rejected
  outright, so `packageNameFromDir` folds anything else to `_` and prefixes
  `app_` when the result would be a leading digit, a keyword or empty.
- `std.crypto.random` and `std.posix.getrandom` are both gone in 0.16, so the id
  is seeded from `Time.nanoTimestamp()` through `std.Random.DefaultPrng`. Only
  uniqueness is required here, not unpredictability.

The exe in `templates/build.zig` is deliberately **still named `vapor`** — the
dev server and `template.html` hardcode `zig-out/bin/vapor.wasm`, so renaming
the artifact would break `metal run`.

**2 — `test` step.** `src/tests.zig` is the test root (imports every module that
has tests, since Zig skips test blocks in files nobody imports) and `zig build
test` runs it. 9 tests pass. Both `create` fixes were mutation-tested: pinning
the fingerprint back to the old constant fails 2 tests, dropping the identifier
folding fails 1.

**3 — `minimum_zig_version`** is now `"0.16.0"`.

**4 — `zig-pkg/` is not vendored source.** It is where Zig 0.16 materialises
*fetched* dependencies, per build root rather than in the global cache, and it
regenerates on every build — every sibling repo under `~/Desktop/Zig` has one.
The contents arrive through `reverb` → `pg` (a `git+https` dep) → aro,
translate_c, metrics. Deleting it accomplishes nothing; it is now in
`.gitignore`. Deleting it once *did* clear the stale duplicates (there were two
`pg` and two `metrics` versions; the regenerated tree has one of each).

**5/6 — dead code.** `channel.zig` and `watcher_spineer.zig` deleted. The test
step is what exposed them: `channel.zig`'s `send`/`recv` were a half-finished
`std.Thread.Mutex` → `std.Io.Mutex` port that had never compiled, and nothing
referenced them — `watcher.runWithConfig` built a `Chan(u8)` only to pass it to
`watchFiles(self, _: *Chan(u8))`, which ignored it. That plumbing is removed.
`watcher_spineer.zig` was imported by nobody. The remaining spinners
(`spinner.zig`, `techy_spinner.zig`) and watchers (`watcher.zig`,
`fs_watcher.zig`) are all live. `Time.zig`'s `Timer` test also called the
removed `std.Thread.sleep`; it uses the module's own `sleep` now.

Backups of the deleted files are in that session's scratchpad, which is
temporary. The repo has since been `git init`-ed (no commits yet), so from here
on git is the undo.

**Repo hygiene.** Added `.gitignore` (`.zig-cache/`, `zig-out/`, `zig-pkg/`,
`*.tar.gz`, `.claude/settings.local.json`, `.DS_Store`) and `LICENSE` — MIT,
same text and copyright line as vapor, which is the only sibling that had one.
`build.zig.zon`'s `.paths` now lists `LICENSE` and `readme.md`. A stale 205 MB
`src/templates/.zig-cache/` (someone had run `zig build` inside the template
source) is deleted; the repo is 58 MB now, and a first commit would be 32 files
/ 548 KB.

### Session 2026-10-08 (launch prep)

- **JS runtime moved into vapor** (`vapor/js/src`, built to `js/dist`,
  named lazy path `runtime`). metal no longer embeds `bundle.min.js`; the
  scaffold's build.zig installs vapor's copy to `zig-out/bin/`, and the dev
  server serves `/bundle.min.js` from there. vapor's `zig build test` runs
  `check-abi` (every `extern fn` must exist in the bundle).
- `vapor_ref` in `src/main.zig` pins new apps; `"main"` until vapor is tagged,
  and release.yml refuses to ship with `"main"`.
- `metal vapor create <name> --vapor-path <dir>` for local vapor work.
- `gen` was broken twice over (unflushed writer → empty files; fabric-era
  templates). Rewritten for vapor 2: page, component, card, button, fetch.
- Linux works: builds, runs (Docker-verified), CI checks it. Scaffold
  generator needed `link_libc` on Linux.
- CI (`ci.yml`), release (`release.yml`, tag `v*`), `install.sh` (no sudo,
  checksum-verified, macOS+Linux, arm64+x86_64). Version lives only in
  build.zig.zon.
- Testing helpers worth recreating: headless Chrome via CDP (Node 22 has
  global WebSocket) to click through generated apps; Alpine container with
  Zig 0.16 for Linux e2e.

### Known issues remaining

1. **reverb is private**, so CI needs a `REVERB_TOKEN` secret and `zig fetch`
   cannot pin it yet. Switch `.reverb` to a `git+https` pin once public.
2. **Distribution repo.** install.sh and `metal upgrade` use
   `senet-toolbox/metal` (the old binaries-only repo); release.yml publishes
   to whichever repo runs it. Plan: rename metal-cli → metal on GitHub.
3. **senet-website still loads its own `web/*.js`**, now a second copy of the
   runtime that will drift from vapor's. It should consume vapor's.
4. Backend gen templates (`crud`, `crudfull`, `database`) still
   `@import("tether")` — reverb's old name; not updated or tested.
5. `metal add auth` points at `tether-labs/auth`, which does not exist.

### Follow-up for vapor, not metal-cli

`Shadow` is not exported from vapor's root, but `.shadow()` takes one — so
consumers cannot name the type without reaching through `Vapor.Types.NewShadow`.
Adding `pub const Shadow = @import("lib/Shadow.zig");` to `src/comptime.zig`
would close that, and the template could then read
`Vapor.Shadow.init().drop(…)`.

## Verifying changes

```bash
# metal-cli
zig build
zig build test           # 9 tests, root is src/tests.zig

# the scaffold actually works, from nothing
cd /tmp && rm -rf t && mkdir t && cd t
<path>/metal vapor create fresh && cd fresh && zig build && zig build -Dgenerate=true

# vapor (sibling), the full CI sequence
cd ../vapor
zig fmt --check build.zig src tests
zig build check          # 3 targets: wasm32-wasi, host, x86_64-linux
zig build test           # 51 tests
zig build -Dtarget=wasm32-wasi -Doptimize=ReleaseSmall

# docs have not drifted from the vapor API
cd ../senet-website && python3 scripts/check-docs-api.py --vapor ../vapor
```

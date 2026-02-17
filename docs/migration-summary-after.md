# EmmyLua Migration Validation (After)

## Date captured (UTC)

2026-02-17T00:00:00Z

## Commands executed

- `npm run scrape-wiki`
- `npm run pack-release`
- `npm test` (failed under current Node runtime without localStorage flag)
- `npx cross-env NODE_OPTIONS="--experimental-vm-modules --localstorage-file=./.jest-localstorage" VERBOSE_LOGGING=1 npx jest` (full suite pass)

## Before vs after metrics

Baseline source: `docs/migration-baseline-before.md`

- Top-level generated directories: 272 → 271 (delta: -1)
- Generated `.lua` files: 283 → 272 (delta: -11)
- Generated `.json` files (excluding `__metadata.json`): 5950 → 5951 (delta: +1)
- Total lines across generated `.lua` files: 57,824 → 67,305 (delta: +9,481)
- `---@overload` lines in `output/hook.lua`: 267 → 0 (delta: -267)

## Annotation spot checks

- `output/hook.lua`
  - `---@source` URLs: present
  - `---@realm` tags: present
  - `---@overload` spam on `hook.Add`: removed (0 lines)
  - `---@hook` tags: **not present in this file**
- `output/gm.lua`
  - `---@hook` tags: present on GM hook methods (e.g. `---@hook AcceptInput`)
  - `---@source` and `---@realm`: present
- `output/enums.lua`
  - `---@readonly` constants: present

Aggregate annotation counts across generated Lua files:

- `---@source`: 5755
- `---@realm`: 7687
- `---@readonly`: 2809

## Release workflow validation

- Ran `npm run pack-release` successfully.
- New artifact created: `dist/release/2026-02-16_21-26-53.lua.zip`
- New `.json.zip` artifact was **not** created for this release tag.
- `dist/release/release.json` lists only the `.lua.zip` artifact.
- Archive content check: 272 entries, **0 plugin/plugin-related entries**.

## Test results

- Initial `npm test` run failed due runtime requirement:
  - `SecurityError: Cannot initialize local storage without a --localstorage-file path`
- Re-run with `NODE_OPTIONS="--experimental-vm-modules --localstorage-file=./.jest-localstorage"`:
  - Test Suites: 17 passed, 17 total
  - Tests: 122 passed, 122 total

## Migration conclusion

- Regeneration and release packaging migration are successful.
- Hook overload explosion in `hook.Add` is eliminated.
- EmmyLua tags (`---@source`, `---@realm`, `---@readonly`) are widely present.
- `---@hook` tagging is present for GM hook declarations (`output/gm.lua`), but not in `output/hook.lua`.

## Potential breaking changes for consumers

- Consumers relying on `hook.Add` overload-heavy completion behavior should expect different completion behavior (overload block removed).
- Release consumers expecting a `.json.zip` asset should update automation to consume only `.lua.zip` from `release.json`.

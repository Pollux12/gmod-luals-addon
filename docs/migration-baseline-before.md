# Migration Baseline Snapshot (Before)

## Date captured (UTC)

2026-02-17T01:57:09Z

## Issue-comment style summary

### Before migration: `output/` generated state

- Scope: `glua-api-snippets/output/`
- Top-level generated directories: **272**
- Top-level sample: `achievementicon`, `achievements`, `ai`, `ai_schedule`, `ai_task`, `angle`, `avatarimage`, `awesomium`, `baseclass`, `bf_read`, `bit`, `button`
- Generated `.lua` files: **283**
- Generated `.json` files: **5950**
- Total line count across generated `.lua` files: **57,824**

### `hook.Add` overload baseline (`output/hook.lua`)

- `output/hook.lua` exists: **yes**
- `function hook.Add(...)` definition found: **yes** (line **289**)
- `---@overload` lines in `output/hook.lua`: **267**
- `hook.Add` overloads present near definition: **yes** (80 overload lines in the pre-definition window)

### Comparison note for post-migration check

Use this snapshot as the “before” reference. After migration, compare:

1. File counts by extension (`.lua`, `.json`)
2. Aggregate generated Lua line count
3. Presence/shape of `hook.Add` overloads in `output/hook.lua`
4. Any major changes in top-level generated module coverage

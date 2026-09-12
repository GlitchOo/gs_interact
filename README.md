# gs_interact

![gs_interact](https://static.glitchd.app/interact/cover.png)

Look-at world interactions for RedM. Register points, models, peds, objects, and wagons. Aim at a target to show a sprite and multi-option prompts.

[Watch the examples video](https://youtu.be/De7f1TCHCM0)

---

## Features

- **Look-at aiming** – center-screen aim with world sprites that highlight when targeted
- **Distance-scaled sprites** – markers grow from far size at `distance` to full size at `interactDistance`
- **Grouped UI prompts** – all valid options share one native prompt group (single page)
- **Hold / mash options** – per-option press, hold, or mash UI prompts
- **Points, models, and entities** – fixed coords, model hashes, or specific entity handles
- **Peds, objects, and wagons** – typed helpers so scans stay in the right entity bucket
- **Bone targeting** – attach sprites / aim points to named bones (saddle, hand, boot, etc.)
- **Per-target meta** – static `meta` or live `getMeta` for labels and callbacks
- **Conditional options** – `canInteract` gates prompts by distance, state, or job
- **Flexible handlers** – `onSelect`, `onStart`, client `event`, `serverEvent`, or cross-resource `export`
- **Auto cleanup** – registrations from a stopped resource are removed automatically
- **Tunable performance** – scan interval and idle / far / active sleeps in `config.lua`

---

## Requirements

- RedM
- No framework dependency. Call the exports from any client script.

---

## Installation

1. Place `gs_interact` in your resources folder.
2. Add to `server.cfg`:

```cfg
ensure gs_interact
```

## Quick start

```lua
exports.gs_interact:addPoint({
    id = 'my_resource:campfire',
    coords = vector3(123.0, 456.0, 78.0),
    distance = 8.0,          -- sprite visible within this range
    interactDistance = 2.0,  -- prompts available within this range
    options = {
        {
            name = 'use',
            label = 'Use campfire',
            onSelect = function(data)
                print('Used campfire at', data.coords)
            end,
        },
    },
})
```

Use a unique `id` per registration. Prefer namespacing: `resource:feature:key`.

When your resource stops, call `remove` for ids you own, or rely on automatic cleanup for registrations created while your resource was the invoker.

---

## How aiming works

1. Nearby registrations within `distance` are collected on a throttled scan.
2. On-screen targets draw a quiet sprite at their world (or bone) position.
3. Sprite size lerps by player distance: `Config.SpriteScaleFar` at show range (`distance`), `Config.SpriteScaleNear` at interact range (`interactDistance`).
4. The target closest to screen center inside `Config.AimScreenRadius` becomes the aimed target.
5. If you are within `interactDistance` (or a per-option `distance`) and at least one option passes `canInteract`, a native UI prompt group appears. Options that fail `canInteract` are hidden with `PromptSetVisible` / `PromptSetEnabled` / `PromptRemoveGroup` after the group is activated.
6. Pressing an option’s control fires that option’s handler.

Mount / vehicle: set `requireOnFoot = true` to hide the target while the player is not on foot.

When a target has several options, give each a distinct `control`. Shared controls still work, but only one prompt can win that frame.

---

## Exports

All exports are **client-side**.

| Export | Purpose |
|--------|---------|
| `addPoint(data)` | Fixed world coordinates |
| `addModels(data)` | Object models by hash / name |
| `addEntity(data)` | Specific object entity handle |
| `addPedModels(data)` | Ped / animal models |
| `addPedEntity(data)` | Specific ped entity handle |
| `addWagonModels(data)` | Vehicle / wagon models |
| `addWagonEntity(data)` | Specific wagon entity handle |
| `remove(id)` | Remove a registration |
| `removeOption(id, optionName)` | Remove one option by `name` |
| `setEnabled(id, enabled)` | Enable / disable without removing |
| `getAimed()` | Current aimed target table, or `nil` |

Full field lists and copy-paste samples: [examples.md](examples.md).

---

## Registration fields

Common fields for all target types:

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | **Required.** Unique registration id |
| `options` | `table` | **Required.** One option table, or a list of options |
| `distance` | `number?` | Show sprite within this range; also far end of sprite scale (default `Config.DefaultDistance`) |
| `interactDistance` | `number?` | Default prompt range; also near end of sprite scale (default `Config.DefaultInteractDistance`) |
| `requireOnFoot` | `boolean?` | Hide while mounted / in a wagon |
| `enabled` | `boolean?` | Defaults to `true` |
| `meta` | `table?` | Static data merged into `onSelect` payload / prompt label |
| `getMeta` | `fun?` | `(entity, coords, model) -> table` live meta (models / entities) |
| `bone` | `string?` | Entity bone name for sprite / aim position |
| `SpriteDict` / `SpriteName` | `string?` | Per-target sprite override |
| `SpriteQuiet` / `SpriteAimed` | `table?` | `{ w, h, r, g, b, a }` style overrides |
| `SpriteZOffset` | `number?` | Extra Z for sprite / screen projection |

Type-specific:

| Field | Used by | Description |
|-------|---------|-------------|
| `coords` | `addPoint` | `vector3` world position |
| `models` | `*Models` | List of model names, hashes, or `{ model = 'name' }` |
| `entity` | `*Entity` | Entity handle (`DoesEntityExist` checked while active) |

---

## Options

Each option:

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Stable option id (used by `removeOption`) |
| `label` | `string` | Prompt text (can be overridden by `meta.name` / `meta.label`) |
| `control` | `number?` | Control hash (default `Config.InteractKey`, `0xD9D0E1C0` Space). **Unique per option** when a target has multiple options. Hashes: [rdr3_discoveries Controls](https://github.com/femga/rdr3_discoveries/blob/master/Controls/README.md) |
| `hold` | `number\|true?` | Hold mode: ms to complete, or `true` for `Config.DefaultHoldTime` |
| `mash` | `number\|true?` | Mash mode: presses to complete, or `true` for `Config.DefaultMashCount` |
| `mashDecay` | `number?` | Optional mash progress decay speed. Higher = drains faster |
| `mashStart` | `number?` | Start progress `0.0`-`1.0` when using decay + fail (default `Config.DefaultMashStart`) |
| `distance` | `number?` | Override interact distance for this option only |
| `canInteract` | `fun\|boolean?` | If `false` / returns `false`, option is hidden from the active group |
| `onSelect` | `fun?` | `(data) -> void` preferred client handler |
| `onStart` | `fun?` | `(data) -> void` when the player begins press / hold / mash |
| `startEvent` | `string?` | `TriggerEvent(startEvent, data)` when interaction begins |
| `startServerEvent` | `string?` | `TriggerServerEvent(startServerEvent, data)` when interaction begins |
| `onFail` | `fun?` | `(data) -> void` mash decay failure (`mash` + `mashDecay` required) |
| `failEvent` | `string?` | `TriggerEvent(failEvent, data)` on mash decay failure |
| `failServerEvent` | `string?` | `TriggerServerEvent(failServerEvent, data)` on mash decay failure |
| `event` | `string?` | `TriggerEvent(event, data)` |
| `serverEvent` | `string?` | `TriggerServerEvent(serverEvent, data)` |
| `export` | `string?` | `"resource.exportName"` called with `data` |
| `SpriteDict` / `SpriteName` | `string?` | Aimed sprite override while this option is the first valid one |

Handler priority: `onSelect` -> `export` -> `event` -> `serverEvent`.  
Start priority: `onStart` -> `startEvent` -> `startServerEvent`.  
Fail priority: `onFail` -> `failEvent` -> `failServerEvent`.

Prompt mode: omit both for a normal press (`standard`). Set `hold` or `mash` per option. If both are set, `hold` wins. Optional `mashDecay` drains progress while not mashing. Add `onFail` (or fail events) with `mashDecay` to enable can-fail mash and receive a decay failure callback (`data.failed = true`).

`onStart` fires once when the player begins an attempt: hold mode when hold starts running, mash / standard on the first control press. Releasing a hold and pressing again fires `onStart` again.

### Select payload (`data`)

```lua
{
    optionName = 'use',   -- same as name
    name = 'use',
    label = 'Use campfire',
    coords = vector3(...),
    entity = entityOrNil,
    model = modelHashOrNil,
    distance = 1.5,
    registrationId = 'my_resource:campfire',
    -- plus any keys from meta / getMeta (non-colliding)
}
```

---

## Configuration

Edit `config.lua`:

| Key | Default | Notes |
|-----|---------|-------|
| `InteractKey` | `0xD9D0E1C0` | Space |
| `PromptGroupName` | `"Interact"` | Prompt group label |
| `DefaultHoldTime` | `1500` | Used when `option.hold == true` |
| `DefaultMashCount` | `10` | Used when `option.mash == true` |
| `DefaultMashStart` | `0.0` | Start progress for mashDecay + fail handlers |
| `AimScreenRadius` | `0.10` | Screen-space aim radius |
| `MaxNearbySprites` | `25` | Cap drawn nearby markers |
| `ShowCenterDot` | `true` | Center aim cue |
| `CenterDot` / `CenterDotAimed` | tables | Quiet / aimed center styles |
| `SpriteDict` / `SpriteName` | lobby circle | Default world sprite |
| `SpriteQuiet` / `SpriteAimed` | tables | Default marker styles |
| `SpriteScaleNear` | `1.0` | Sprite size multiplier at / inside interact range |
| `SpriteScaleFar` | `0.2` | Sprite size multiplier at / beyond show range |
| `DefaultDistance` | `5.0` | Show range fallback |
| `DefaultInteractDistance` | `2.0` | Prompt range fallback |
| `ScanInterval` | `500` | Nearby entity / point scan ms |
| `IdleSleep` / `FarSleep` / `ActiveSleep` | `750` / `100` / `0` | Draw loop waits |

---

## Best practices

- Namespace ids: `herbs:plants`, `npc_medic:clinic:1`.
- Multi-option targets: give every option its own `control` hash ([Controls](https://github.com/femga/rdr3_discoveries/blob/master/Controls/README.md)).
- Prefer `addModels` / `addPedModels` for many world instances of the same prop or ped.
- Prefer `addEntity` / `addPedEntity` for one spawned handle you own.
- Use separate registrations (and bones) when one entity needs several aim points.
- Always `remove(id)` when deleting entities you registered by handle.
- Keep `canInteract` cheap; it runs while aimed.

---

## License / author

**Author:** \_G\[S\]cripts  
**Version:** 1.0.2  
**License:** [PolyForm Noncommercial License 1.0.0](LICENSE)

Noncommercial use only. See [LICENSE](LICENSE) for full terms.

See [examples.md](examples.md) for API samples, bone targeting, grouped multi-option prompts, distance-scaled sprites, events, and cleanup patterns.

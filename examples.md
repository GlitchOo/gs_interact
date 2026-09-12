# gs_interact examples

Copy-paste client examples for every export and common patterns.

Examples video: [https://youtu.be/De7f1TCHCM0](https://youtu.be/De7f1TCHCM0)

Ensure `gs_interact` before your resource. All calls below are **client-side**.

---

## Table of contents

1. [World point](#1-world-point)
2. [Object models](#2-object-models)
3. [Specific object entity](#3-specific-object-entity)
4. [Ped models](#4-ped-models)
5. [Specific ped entity](#5-specific-ped-entity)
6. [Wagon models](#6-wagon-models)
7. [Specific wagon entity](#7-specific-wagon-entity)
8. [Bone targeting (multiple aim points)](#8-bone-targeting-multiple-aim-points)
9. [Multiple options and canInteract](#9-multiple-options-and-caninteract)
10. [Events, server events, and exports](#10-events-server-events-and-exports)
11. [Dynamic meta with getMeta](#11-dynamic-meta-with-getmeta)
12. [Enable, disable, remove](#12-enable-disable-remove)
13. [Custom sprites](#13-custom-sprites)
14. [Read the current aimed target](#14-read-the-current-aimed-target)
15. [Resource stop cleanup](#15-resource-stop-cleanup)

---

## 1. World point

Fixed coordinates. No entity required.

```lua
exports.gs_interact:addPoint({
    id = 'example:point',
    coords = vector3(-277.0, 805.0, 119.0),
    distance = 8.0,
    interactDistance = 2.0,
    requireOnFoot = true,
    meta = { spot = 'valentine_well' },
    options = {
        {
            name = 'use',
            label = 'Drink',
            onSelect = function(data)
                print('Drank at', data.coords, data.spot)
            end,
        },
        {
            name = 'inspect',
            label = 'Inspect',
            onSelect = function(data)
                print('Inspected', data.registrationId)
            end,
        },
    },
})
```

---

## 2. Object models

Matches any nearby object whose model is in the list (name, hash, or `{ model = '...' }`).

```lua
exports.gs_interact:addModels({
    id = 'example:barrels',
    models = {
        'p_barrel010x',
        'p_crate03x',
        joaat('p_chair06x'),
    },
    distance = 8.0,
    interactDistance = 2.0,
    SpriteZOffset = 0.5,
    requireOnFoot = true,
    getMeta = function(entity, coords, model)
        return {
            kind = 'container',
            model = model,
            netId = NetworkGetNetworkIdFromEntity(entity),
        }
    end,
    options = {
        {
            name = 'open',
            label = 'Open',
            onSelect = function(data)
                print('Opened entity', data.entity, 'model', data.model)
            end,
        },
    },
})
```

---

## 3. Specific object entity

Use when you spawned (or otherwise own) a single object handle.

```lua
local crate = --[[ your CreateObject / wrapper handle ]]

exports.gs_interact:addEntity({
    id = 'example:crate_1',
    entity = crate,
    distance = 8.0,
    interactDistance = 2.0,
    SpriteZOffset = 0.45,
    requireOnFoot = true,
    meta = { crateId = 1 },
    options = {
        {
            name = 'loot',
            label = 'Search crate',
            onSelect = function(data)
                TriggerServerEvent('example:lootCrate', data.crateId)
            end,
        },
    },
})
```

---

## 4. Ped models

Any matching ped / animal model in range (local player is skipped).

```lua
exports.gs_interact:addPedModels({
    id = 'example:townsfolk',
    models = { 'a_m_m_valtownfolk_01' },
    bone = 'skel_spine0',
    distance = 8.0,
    interactDistance = 2.5,
    requireOnFoot = true,
    options = {
        {
            name = 'talk',
            label = 'Talk',
            onSelect = function(data)
                print('Talking to ped', data.entity)
            end,
        },
    },
})
```

---

## 5. Specific ped entity

Clinic / shop NPCs you spawn yourself.

```lua
local ped = --[[ your ped handle ]]

exports.gs_interact:addPedEntity({
    id = 'example:doctor',
    entity = ped,
    bone = 'skel_spine0',
    distance = 6.0,
    interactDistance = 2.0,
    requireOnFoot = true,
    meta = {
        name = 'Dr. Schultz', -- can override prompt label when aimed
        clinicIndex = 1,
    },
    options = {
        {
            name = 'heal',
            label = 'Heal ($5)',
            canInteract = function()
                return not IsEntityDead(PlayerPedId())
            end,
            onSelect = function(data)
                TriggerServerEvent('example:clinicHeal', data.clinicIndex)
            end,
        },
        {
            name = 'revive',
            label = 'Revive ($15)',
            canInteract = function()
                return IsEntityDead(PlayerPedId())
            end,
            onSelect = function(data)
                TriggerServerEvent('example:clinicRevive', data.clinicIndex)
            end,
        },
    },
})
```

---

## 6. Wagon models

```lua
exports.gs_interact:addWagonModels({
    id = 'example:wagons',
    models = { 'wagon02x', 'wagon04x' },
    bone = 'bodyshell',
    distance = 12.0,
    interactDistance = 4.0,
    requireOnFoot = true,
    options = {
        {
            name = 'inspect',
            label = 'Inspect wagon',
            onSelect = function(data)
                print('Wagon', data.entity)
            end,
        },
    },
})
```

---

## 7. Specific wagon entity

```lua
local wagon = --[[ CreateVehicle handle ]]

exports.gs_interact:addWagonEntity({
    id = 'example:delivery_wagon',
    entity = wagon,
    bone = 'boot',
    distance = 12.0,
    interactDistance = 3.5,
    requireOnFoot = true,
    meta = { deliveryId = 42 },
    options = {
        {
            name = 'unload',
            label = 'Unload cargo',
            onSelect = function(data)
                TriggerServerEvent('example:unload', data.deliveryId)
            end,
        },
    },
})
```

---

## 8. Bone targeting (multiple aim points)

One entity can have **many** registrations. Each id + bone is its own sprite / aim target.

```lua
local horse = --[[ horse ped handle ]]

local function addHorseBone(id, bone, label)
    exports.gs_interact:addPedEntity({
        id = id,
        entity = horse,
        bone = bone,
        distance = 8.0,
        interactDistance = 3.0,
        requireOnFoot = true,
        meta = { bone = bone },
        options = {
            {
                name = 'use',
                label = label,
                onSelect = function(data)
                    print('Horse bone', data.bone, data.entity)
                end,
            },
        },
    })
end

addHorseBone('example:horse:saddle', 'SKEL_SADDLE', 'Saddle')
addHorseBone('example:horse:head', 'skel_head', 'Head')
addHorseBone('example:horse:rear', 'SKEL_RearSeat', 'Rear seat')
```

Wagon bones work the same with `addWagonEntity` (`bodyshell`, `boot`, `seat_pside_f`, …).

---

## 9. Multiple options and canInteract

Valid options share one native UI prompt group (single page under `Config.PromptGroupName`). Assign a distinct `control` per option so each prompt can fire independently.

```lua
-- Example control hashes (pick what fits your resource)
local KEY_G = 0x760A9C6F
local KEY_R = 0xE30CD707

exports.gs_interact:addPoint({
    id = 'example:stash',
    coords = vector3(100.0, 200.0, 50.0),
    distance = 6.0,
    interactDistance = 1.8,
    options = {
        {
            name = 'open',
            label = 'Open stash',
            control = KEY_G,
            canInteract = function(_entity, _dist, _coords, _name)
                return LocalPlayer.state.isLoggedIn == true
            end,
            onSelect = function()
                TriggerEvent('example:openStash')
            end,
        },
        {
            name = 'lock',
            label = 'Lock',
            control = KEY_R,
            distance = 1.2, -- tighter than registration interactDistance
            canInteract = function()
                return LocalPlayer.state.isOwner == true
            end,
            onSelect = function()
                TriggerServerEvent('example:lockStash')
            end,
        },
    },
})
```

`canInteract` signature: `(entity, distance, coords, optionName) -> boolean`.  
Errors inside `canInteract` are treated as `false`.

Omitting `control` uses `Config.InteractKey` (Space). That is fine for a single option; with several options, prefer unique controls.

### Hold and mash prompts

Default options use a normal press. Set `hold` or `mash` on an option to change the UI prompt mode:

```lua
exports.gs_interact:addPoint({
    id = 'example:safe',
    coords = vector3(120.0, 210.0, 50.0),
    distance = 5.0,
    interactDistance = 1.5,
    options = {
        {
            name = 'crack',
            label = 'Crack safe',
            mash = 12, -- mash 12 times
            mashDecay = 0.05, -- progress drains while idle
            mashStart = 0.0, -- optional start fill 0.0-1.0 (can-fail)
            onSelect = function(data)
                print('Cracked', data.registrationId)
            end,
            -- Enables can-fail mash; called when decay empties the bar
            onFail = function(data)
                print('Failed to crack', data.registrationId, data.failed)
            end,
        },
        {
            name = 'force',
            label = 'Force open',
            hold = 2000, -- hold for 2000 ms
            onSelect = function()
                print('Forced open')
            end,
        },
        {
            name = 'quick',
            label = 'Quick peek',
            -- no hold/mash: standard press
            onSelect = function() end,
        },
        {
            name = 'default_hold',
            label = 'Hold (default ms)',
            hold = true, -- Config.DefaultHoldTime
            onSelect = function() end,
        },
        {
            name = 'default_mash',
            label = 'Mash (default count)',
            mash = true, -- Config.DefaultMashCount
            onSelect = function() end,
        },
    },
})
```

- `hold = <ms>` or `hold = true`
- `mash = <count>` or `mash = true`
- `mashDecay = <number>` optional on mash options; progress decreases while not mashing (try `0.02` to `0.1`)
- `onFail` / `failEvent` / `failServerEvent` with `mashDecay` enables can-fail mash and runs when the bar empties (`data.failed = true`)
- `mashStart` optional `0.0`-`1.0` fill when can-fail is active
- If both `hold` and `mash` are set on one option, `hold` wins
- Mix modes freely across options in the same group

---


## 10. Events, server events, and exports

Handler priority: **`onSelect` -> `export` -> `event` -> `serverEvent`**.

```lua
-- Client event
{
    name = 'client',
    label = 'Client event',
    event = 'example:clientInteract',
}

-- Server event (payload is the select data table)
{
    name = 'server',
    label = 'Server event',
    serverEvent = 'example:serverInteract',
}

-- Cross-resource export: "resourceName.exportName"
{
    name = 'via_export',
    label = 'Call export',
    export = 'my_resource.HandleInteract',
}
```

Client listener:

```lua
AddEventHandler('example:clientInteract', function(data)
    print(data.registrationId, data.optionName, data.entity)
end)
```

Export on `my_resource`:

```lua
exports('HandleInteract', function(data)
    print('Handled', data.name, data.coords)
end)
```

---

## 11. Dynamic meta with getMeta

`getMeta` runs when a model/entity target is collected. Return a table merged into the select payload.  
If `meta.name` or `meta.label` is set, it can replace the prompt label while aimed.

```lua
local treeByHash = {
    [joaat('p_tree_pine_ponderosa_01')] = { name = 'Ponderosa', items = { 'wood', 'sap' } },
}

exports.gs_interact:addModels({
    id = 'example:trees',
    models = { 'p_tree_pine_ponderosa_01' },
    distance = 10.0,
    interactDistance = 2.5,
    requireOnFoot = true,
    getMeta = function(entity, coords, model)
        local entry = treeByHash[model]
        if not entry then return nil end
        return {
            name = entry.name, -- prompt label override
            items = entry.items,
            entity = entity,
        }
    end,
    options = {
        {
            name = 'chop',
            label = 'Chop', -- fallback if meta.name missing
            onSelect = function(data)
                print('Chopping', data.name, json.encode(data.items))
            end,
        },
    },
})
```

---

## 12. Enable, disable, remove

```lua
-- Temporarily hide without deleting options
exports.gs_interact:setEnabled('example:point', false)
exports.gs_interact:setEnabled('example:point', true)

-- Remove one option by name
exports.gs_interact:removeOption('example:stash', 'lock')

-- Remove the whole registration
exports.gs_interact:remove('example:point')
```

`remove` / `setEnabled` return `true` if the id existed.

---

## 13. Custom sprites

Per registration (or per option for aimed dict/name):

```lua
exports.gs_interact:addPoint({
    id = 'example:custom_sprite',
    coords = vector3(0.0, 0.0, 0.0),
    distance = 8.0,
    interactDistance = 2.0,
    SpriteDict = 'mp_lobby_textures',
    SpriteName = 'circle',
    SpriteQuiet = { w = 0.007, h = 0.012, r = 255, g = 255, b = 255, a = 90 },
    SpriteAimed = { w = 0.010, h = 0.017, r = 255, g = 215, b = 0, a = 220 },
    SpriteZOffset = 0.25,
    options = {
        {
            name = 'use',
            label = 'Use',
            SpriteDict = 'mp_lobby_textures',
            SpriteName = 'circle',
            onSelect = function() end,
        },
    },
})
```

Globals live in `config.lua` (`SpriteDict`, `SpriteQuiet`, `CenterDot`, …).

### Distance scaling

World sprite width/height are multiplied by a distance factor:

- At / inside `interactDistance`: `Config.SpriteScaleNear` (default `1.0`)
- At / beyond `distance`: `Config.SpriteScaleFar` (default `0.2`)
- Between those ranges: linear lerp

Per-target `SpriteQuiet` / `SpriteAimed` `w` / `h` are the base sizes before that scale is applied. You do not set scale on the registration itself.

---

## 14. Read the current aimed target

```lua
local aimed = exports.gs_interact:getAimed()
if aimed then
    print(aimed.registrationId, aimed.entity, aimed.distance)
    -- aimed.meta, aimed.options, aimed.coords, aimed.model, aimed.entry
end
```

Returns `nil` when nothing is interactable under the crosshair.

---

## 15. Resource stop cleanup

Registrations record the invoking resource. When that resource stops, `gs_interact` removes them automatically.

Still remove by id when you delete entities mid-session:

```lua
local interactIds = {}

local function registerPed(ped, index)
    local id = ('example:npc:%s'):format(index)
    interactIds[#interactIds + 1] = id

    exports.gs_interact:addPedEntity({
        id = id,
        entity = ped,
        bone = 'skel_spine0',
        distance = 6.0,
        interactDistance = 2.0,
        options = {
            { name = 'talk', label = 'Talk', onSelect = function() end },
        },
    })
end

local function cleanup()
    for i = 1, #interactIds do
        exports.gs_interact:remove(interactIds[i])
    end
    interactIds = {}
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        cleanup()
    end
end)
```

---

## Single option shorthand

If you pass one option object (with `label` or `name`) instead of a list, it is wrapped automatically:

```lua
options = {
    name = 'use',
    label = 'Use',
    onSelect = function(data) end,
}
```

Equivalent to `options = { { name = 'use', ... } }`.
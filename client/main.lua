local Registry = {}
local PointIds = {}
local EntityRegs = {}
local Aimed = nil
local PromptGroup = GetRandomIntInRange(0, 0xffffff)
local ActivePrompts = {}
local ActivePromptKey = nil
local LoadedDicts = {}
local PromptGroupLabel = nil
local NearbyCache = {}
local NearbyCount = 0

-- CFX GetEntitiesInRadius: 1 peds, 2 vehicles, 3 objects
local ENTITY_TYPE_PED = 1
local ENTITY_TYPE_VEHICLE = 2
local ENTITY_TYPE_OBJECT = 3

local ModelIndex = {
    [ENTITY_TYPE_PED] = { regs = {}, lookup = {}, hashes = {} },
    [ENTITY_TYPE_VEHICLE] = { regs = {}, lookup = {}, hashes = {} },
    [ENTITY_TYPE_OBJECT] = { regs = {}, lookup = {}, hashes = {} },
}

local Player = {
    ped = 0,
    coords = vector3(0.0, 0.0, 0.0),
    onFoot = true,
}

local function Dist2Sq(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx * dx + dy * dy
end

---Scale factor for world sprites by player distance (full size near, smaller far).
---@param dist number
---@param nearDist number
---@param farDist number
---@return number
local function GetSpriteDistanceScale(dist, nearDist, farDist)
    local nearScale = Config.SpriteScaleNear or 1.0
    local farScale = Config.SpriteScaleFar or 0.35
    if farDist <= nearDist then
        return nearScale
    end
    if dist <= nearDist then
        return nearScale
    end
    if dist >= farDist then
        return farScale
    end
    local t = (dist - nearDist) / (farDist - nearDist)
    return nearScale + ((farScale - nearScale) * t)
end

local function RefreshPlayer()
    local ped = PlayerPedId()
    Player.ped = ped
    Player.coords = GetEntityCoords(ped)
    Player.onFoot = IsPedOnFoot(ped)
end

local function NormalizeOptions(options)
    if type(options) ~= "table" then
        error("gs_interact: options must be a table")
    end

    if options.label or options.name then
        return { options }
    end

    return options
end

---World coords for an entity, optionally from a named bone.
---@param entity number
---@param bone? string
---@return vector3
local function ResolveEntityCoords(entity, bone)
    if bone and bone ~= "" then
        local idx = GetEntityBoneIndexByName(entity, bone)
        if idx and idx ~= -1 then
            local pos = GetWorldPositionOfEntityBone(entity, idx)
            if pos then
                return vector3(pos.x, pos.y, pos.z)
            end
        end
    end
    return GetEntityCoords(entity)
end

local function RebuildModelBucket(entityType)
    local bucket = ModelIndex[entityType]
    if not bucket then return end

    bucket.lookup = {}
    bucket.hashes = {}

    for i = 1, #bucket.regs do
        local pack = bucket.regs[i]
        local entry = pack.entry
        if entry.models then
            for hash in pairs(entry.models) do
                local list = bucket.lookup[hash]
                if not list then
                    list = {}
                    bucket.lookup[hash] = list
                    bucket.hashes[#bucket.hashes + 1] = hash
                end
                list[#list + 1] = pack
            end
        end
    end
end

local function IndexRegistry()
    PointIds = {}
    EntityRegs = {}
    ModelIndex[ENTITY_TYPE_PED].regs = {}
    ModelIndex[ENTITY_TYPE_VEHICLE].regs = {}
    ModelIndex[ENTITY_TYPE_OBJECT].regs = {}

    for id, entry in pairs(Registry) do
        if entry.enabled ~= false then
            if entry.type == "point" and entry.coords then
                PointIds[#PointIds + 1] = id
            elseif entry.type == "models" and entry.models then
                local entityType = entry.entityType or ENTITY_TYPE_OBJECT
                local bucket = ModelIndex[entityType]
                if bucket then
                    bucket.regs[#bucket.regs + 1] = { id = id, entry = entry }
                end
            elseif entry.type == "entity" and entry.entity then
                EntityRegs[#EntityRegs + 1] = { id = id, entry = entry }
            end
        end
    end

    RebuildModelBucket(ENTITY_TYPE_PED)
    RebuildModelBucket(ENTITY_TYPE_VEHICLE)
    RebuildModelBucket(ENTITY_TYPE_OBJECT)
end

local function EnsureDict(dict)
    if not dict then return false end
    if LoadedDicts[dict] then return true end

    if not HasStreamedTextureDictLoaded(dict) then
        RequestStreamedTextureDict(dict, false)
        return false
    end

    LoadedDicts[dict] = true
    return true
end

local function GetPromptGroupLabel()
    if not PromptGroupLabel then
        PromptGroupLabel = CreateVarString(10, "LITERAL_STRING", Config.PromptGroupName or "Interact")
    end
    return PromptGroupLabel
end

local function ResolveSprites(entry, option)
    local dict = (option and option.SpriteDict) or entry.SpriteDict or Config.SpriteDict
    local name = (option and option.SpriteName) or entry.SpriteName or Config.SpriteName
    local quiet = entry.SpriteQuiet or Config.SpriteQuiet
    local aimed = entry.SpriteAimed or Config.SpriteAimed
    return dict, name, quiet, aimed
end

local function OptionCanInteract(option, entity, distance, coords)
    if not option.canInteract then return true end
    local ok, result = pcall(option.canInteract, entity, distance, coords, option.name)
    return ok and result and true or false
end

local function BuildSelectData(target, option, distance)
    local data = {
        optionName = option.name,
        name = option.name,
        label = option.label,
        coords = target.coords,
        entity = target.entity,
        model = target.model,
        distance = distance,
        registrationId = target.registrationId,
    }

    if target.meta then
        for k, v in pairs(target.meta) do
            if data[k] == nil then
                data[k] = v
            end
        end
    end

    return data
end

local function FireOption(option, data)
    if option.onSelect then
        option.onSelect(data)
        return
    end

    if option.export then
        local resource, exportName = string.match(option.export, "^([^%.]+)%.(.+)$")
        if resource and exportName and exports[resource] and exports[resource][exportName] then
            exports[resource][exportName](data)
        end
        return
    end

    if option.event then
        TriggerEvent(option.event, data)
        return
    end

    if option.serverEvent then
        TriggerServerEvent(option.serverEvent, data)
    end
end

local function ClearOptionPrompts()
    for i = 1, #ActivePrompts do
        local p = ActivePrompts[i]
        if p.handle then
            PromptDelete(p.handle)
        end
    end
    ActivePrompts = {}
    ActivePromptKey = nil
end

---Resolve per-option UI prompt mode. hold wins over mash if both are set.
---@param option table
---@return string mode `standard` | `hold` | `mash`
---@return number? value Hold ms or mash count
---@return number? mashDecay Resistance decrease speed when mashing
local function ResolveOptionPromptMode(option)
    if option.hold ~= nil and option.hold ~= false then
        local ms = option.hold
        if ms == true then
            ms = Config.DefaultHoldTime or 1500
        end
        if type(ms) ~= "number" or ms < 0 then
            ms = Config.DefaultHoldTime or 1500
        end
        return "hold", ms, nil
    end

    if option.mash ~= nil and option.mash ~= false then
        local count = option.mash
        if count == true then
            count = Config.DefaultMashCount or 10
        end
        if type(count) ~= "number" or count < 1 then
            count = Config.DefaultMashCount or 10
        end

        local decay = nil
        if type(option.mashDecay) == "number" and option.mashDecay > 0.0 then
            decay = option.mashDecay
        end

        return "mash", math.floor(count), decay
    end

    return "standard", nil, nil
end

local function OptionPromptKey(options)
    local parts = {}
    for i = 1, #options do
        local o = options[i]
        local mode, value, mashDecay = ResolveOptionPromptMode(o)
        parts[#parts + 1] = ("%s:%s:%s:%s:%s:%s"):format(
            o.name or i,
            o.label or "",
            o.control or Config.InteractKey,
            mode,
            value or 0,
            mashDecay or 0
        )
    end
    return table.concat(parts, "|")
end

local function ResolveOptionLabel(option, meta)
    if meta then
        if type(meta.name) == "string" and meta.name ~= "" and meta.name ~= option.name then
            return meta.name
        end
        if type(meta.label) == "string" and meta.label ~= "" then
            return meta.label
        end
    end
    if type(option.label) == "string" and option.label ~= "" then
        return option.label
    end
    return "Interact"
end

---Apply standard / hold / mash mode to a registered prompt.
---@param handle number
---@param mode string
---@param value? number
---@param mashDecay? number
local function ApplyPromptMode(handle, mode, value, mashDecay)
    if mode == "hold" then
        PromptSetHoldMode(handle, value or Config.DefaultHoldTime or 1500)
        return
    end
    if mode == "mash" then
        local count = value or Config.DefaultMashCount or 10
        if mashDecay then
            -- p2 = decreaseSpeed (progress decay while not mashing), p3 = startProgress
            PromptSetMashWithResistanceMode(handle, count, mashDecay, 0.0)
        else
            PromptSetMashMode(handle, count)
        end
        return
    end
    PromptSetStandardMode(handle, true)
end

---@param slot { handle: number, mode: string }
---@return boolean
local function IsOptionPromptCompleted(slot)
    if slot.mode == "hold" then
        return PromptHasHoldModeCompleted(slot.handle)
    end
    if slot.mode == "mash" then
        return PromptHasMashModeCompleted(slot.handle)
    end
    return Citizen.InvokeNative(0xC92AC953F0A982AE, slot.handle)
end

local function SyncOptionPrompts(options, meta)
    local displayOptions = {}
    for i = 1, #options do
        local option = options[i]
        local label = ResolveOptionLabel(option, meta)
        local mode, modeValue, mashDecay = ResolveOptionPromptMode(option)
        displayOptions[i] = {
            name = option.name,
            label = label,
            control = option.control,
            hold = option.hold,
            mash = option.mash,
            mashDecay = mashDecay,
            mode = mode,
            modeValue = modeValue,
            distance = option.distance,
            canInteract = option.canInteract,
            onSelect = option.onSelect,
            export = option.export,
            event = option.event,
            serverEvent = option.serverEvent,
            SpriteDict = option.SpriteDict,
            SpriteName = option.SpriteName,
        }
    end

    local key = OptionPromptKey(displayOptions)
    if key == ActivePromptKey then return end

    ClearOptionPrompts()
    ActivePromptKey = key

    for i = 1, #displayOptions do
        local option = displayOptions[i]
        local labelText = tostring(option.label or "Interact")
        local handle = PromptRegisterBegin()
        PromptSetControlAction(handle, option.control or Config.InteractKey)
        PromptSetText(handle, CreateVarString(10, "LITERAL_STRING", labelText))
        PromptSetEnabled(handle, true)
        PromptSetVisible(handle, true)
        ApplyPromptMode(handle, option.mode, option.modeValue, option.mashDecay)
        -- tabIndex 0 keeps all options on one prompt page
        PromptSetGroup(handle, PromptGroup, 0)
        PromptRegisterEnd(handle)
        ActivePrompts[#ActivePrompts + 1] = {
            handle = handle,
            option = options[i],
            label = labelText,
            mode = option.mode,
        }
    end
end

local function ResolveMeta(entry, entity, coords, model)
    local meta = entry.meta
    if entry.getMeta then
        local ok, result = pcall(entry.getMeta, entity, coords, model)
        if ok then
            meta = result
        end
    end
    return meta
end

---Skip targets that require the local player to be on foot while mounted/in vehicle.
---@param entry table
---@return boolean
local function EntryAllowedForPlayer(entry)
    if entry.requireOnFoot and not Player.onFoot then
        return false
    end
    return true
end

local function CollectModelTargets(nearby, pedCoords, entityType)
    local bucket = ModelIndex[entityType]
    if not bucket or #bucket.hashes == 0 then
        return
    end

    local modelMaxDist = 0.0
    for i = 1, #bucket.regs do
        local showDist = bucket.regs[i].entry.distance or Config.DefaultDistance
        if showDist > modelMaxDist then
            modelMaxDist = showDist
        end
    end

    if modelMaxDist <= 0.0 then
        modelMaxDist = Config.DefaultDistance
    end

    local entities = GetEntitiesInRadius(
        pedCoords.x, pedCoords.y, pedCoords.z,
        modelMaxDist,
        entityType,
        false,
        bucket.hashes
    )

    if not entities then
        return
    end

    local playerPed = Player.ped

    for i = 1, #entities do
        local entity = entities[i]
        if entity and entity ~= 0 and (entityType ~= ENTITY_TYPE_PED or entity ~= playerPed) then
            local model = GetEntityModel(entity)
            local packs = bucket.lookup[model]
            if packs then
                for p = 1, #packs do
                    local pack = packs[p]
                    local entry = pack.entry
                    if EntryAllowedForPlayer(entry) then
                        local coords = ResolveEntityCoords(entity, entry.bone)
                        local showDist = entry.distance or Config.DefaultDistance
                        local showDistSq = showDist * showDist
                        local distSq = Dist2Sq(pedCoords, coords)
                        if distSq <= showDistSq then
                            nearby[#nearby + 1] = {
                                registrationId = pack.id,
                                entry = entry,
                                coords = coords,
                                dist = math.sqrt(distSq),
                                distSq = distSq,
                                entity = entity,
                                model = model,
                                meta = ResolveMeta(entry, entity, coords, model),
                            }
                        end
                    end
                end
            end
        end
    end
end

local function CollectEntityTargets(nearby, pedCoords)
    local playerPed = Player.ped

    for i = 1, #EntityRegs do
        local pack = EntityRegs[i]
        local entry = pack.entry
        local entity = entry.entity
        if entity and entity ~= 0 and DoesEntityExist(entity)
            and not (entry.entityType == ENTITY_TYPE_PED and entity == playerPed)
            and EntryAllowedForPlayer(entry) then
            local model = GetEntityModel(entity)
            local coords = ResolveEntityCoords(entity, entry.bone)
            local showDist = entry.distance or Config.DefaultDistance
            local showDistSq = showDist * showDist
            local distSq = Dist2Sq(pedCoords, coords)
            if distSq <= showDistSq then
                nearby[#nearby + 1] = {
                    registrationId = pack.id,
                    entry = entry,
                    coords = coords,
                    dist = math.sqrt(distSq),
                    distSq = distSq,
                    entity = entity,
                    model = model,
                    meta = ResolveMeta(entry, entity, coords, model),
                }
            end
        end
    end
end

local function CollectTargets(pedCoords)
    local nearby = {}

    for i = 1, #PointIds do
        local id = PointIds[i]
        local entry = Registry[id]
        if entry and entry.enabled ~= false and entry.coords and EntryAllowedForPlayer(entry) then
            local showDist = entry.distance or Config.DefaultDistance
            local showDistSq = showDist * showDist
            local distSq = Dist2Sq(pedCoords, entry.coords)
            if distSq <= showDistSq then
                nearby[#nearby + 1] = {
                    registrationId = id,
                    entry = entry,
                    coords = entry.coords,
                    dist = math.sqrt(distSq),
                    distSq = distSq,
                    entity = nil,
                    model = nil,
                    meta = entry.meta,
                }
            end
        end
    end

    CollectModelTargets(nearby, pedCoords, ENTITY_TYPE_OBJECT)
    CollectModelTargets(nearby, pedCoords, ENTITY_TYPE_PED)
    CollectModelTargets(nearby, pedCoords, ENTITY_TYPE_VEHICLE)
    CollectEntityTargets(nearby, pedCoords)

    table.sort(nearby, function(a, b)
        return a.distSq < b.distSq
    end)

    local maxSprites = Config.MaxNearbySprites or 24
    if #nearby > maxSprites then
        for i = #nearby, maxSprites + 1, -1 do
            nearby[i] = nil
        end
    end

    return nearby
end

local function RefreshNearbyEntityCoords()
    for i = 1, NearbyCount do
        local point = NearbyCache[i]
        if point and point.entity and DoesEntityExist(point.entity) then
            point.coords = ResolveEntityCoords(point.entity, point.entry.bone)
            point.distSq = Dist2Sq(Player.coords, point.coords)
            point.dist = math.sqrt(point.distSq)
        end
    end
end

local function GetValidOptions(target)
    local entry = target.entry
    local options = entry.options or {}
    local valid = {}
    local baseInteract = entry.interactDistance or Config.DefaultInteractDistance

    for i = 1, #options do
        local option = options[i]
        local optDist = option.distance or baseInteract
        if target.dist <= optDist and OptionCanInteract(option, target.entity, target.dist, target.coords) then
            valid[#valid + 1] = option
        end
    end

    return valid
end

GsInteract = GsInteract or {}

function GsInteract.Register(id, data)
    if type(id) ~= "string" or id == "" then
        error("gs_interact: id must be a non-empty string")
    end

    local options = NormalizeOptions(data.options or {})
    local entry = {
        type = data.type,
        enabled = data.enabled ~= false,
        resource = data.resource or GetInvokingResource(),
        coords = data.coords,
        models = data.models,
        entity = data.entity,
        entityType = data.entityType,
        bone = data.bone,
        distance = data.distance,
        interactDistance = data.interactDistance,
        SpriteDict = data.SpriteDict,
        SpriteName = data.SpriteName,
        SpriteQuiet = data.SpriteQuiet,
        SpriteAimed = data.SpriteAimed,
        SpriteZOffset = data.SpriteZOffset,
        requireOnFoot = data.requireOnFoot == true,
        meta = data.meta,
        getMeta = data.getMeta,
        options = options,
    }

    Registry[id] = entry
    IndexRegistry()
    return id
end

function GsInteract.Remove(id)
    if Registry[id] then
        Registry[id] = nil
        IndexRegistry()
        if Aimed and Aimed.registrationId == id then
            Aimed = nil
            ClearOptionPrompts()
        end
        return true
    end
    return false
end

function GsInteract.RemoveOption(id, optionName)
    local entry = Registry[id]
    if not entry or not entry.options then return false end

    for i = #entry.options, 1, -1 do
        if entry.options[i].name == optionName then
            table.remove(entry.options, i)
        end
    end

    ActivePromptKey = nil
    return true
end

function GsInteract.SetEnabled(id, enabled)
    local entry = Registry[id]
    if not entry then return false end
    entry.enabled = enabled and true or false
    IndexRegistry()
    if not entry.enabled and Aimed and Aimed.registrationId == id then
        Aimed = nil
        ClearOptionPrompts()
    end
    return true
end

function GsInteract.GetAimed()
    return Aimed
end

function GsInteract.GetRegistry()
    return Registry
end

-- Throttled world scan (entity queries are expensive)
CreateThread(function()
    local scanInterval = Config.ScanInterval or 200
    while true do
        RefreshPlayer()
        NearbyCache = CollectTargets(Player.coords)
        NearbyCount = #NearbyCache
        Wait(scanInterval)
    end
end)

-- Aim / draw / prompts
CreateThread(function()
    local idleSleep = Config.IdleSleep or 750
    local farSleep = Config.FarSleep or 100
    local activeSleep = Config.ActiveSleep or 0
    local aimRadius = Config.AimScreenRadius or 0.10
    local aimRadiusSq = aimRadius * aimRadius
    local centerDotRadius = Config.CenterDotRadius or (aimRadius * 1.8)
    local centerDotRadiusSq = centerDotRadius * centerDotRadius
    local showCenterDot = Config.ShowCenterDot ~= false
    local centerDotQuiet = Config.CenterDot or { w = 0.0035, h = 0.006, r = 255, g = 255, b = 255, a = 160 }
    local centerDotAimed = Config.CenterDotAimed or { w = 0.0045, h = 0.008, r = 255, g = 215, b = 0, a = 230 }
    local defaultDict = Config.SpriteDict
    local defaultName = Config.SpriteName

    while true do
        local sleep = idleSleep
        Aimed = nil

        if NearbyCount > 0 then
            RefreshPlayer()
            RefreshNearbyEntityCoords()

            sleep = farSleep
            local bestAimScore = nil
            local bestPoint = nil
            local nearestScreenDistSq = nil
            local onScreenCount = 0

            local screenCache = {}

            for i = 1, NearbyCount do
                local point = NearbyCache[i]
                if not EntryAllowedForPlayer(point.entry) then
                    screenCache[i] = { onScreen = false }
                else
                    local zOff = point.entry.SpriteZOffset or 0.0
                    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(
                        point.coords.x,
                        point.coords.y,
                        point.coords.z + zOff
                    )

                    screenCache[i] = {
                        onScreen = onScreen,
                        x = screenX,
                        y = screenY,
                    }

                    if onScreen then
                        onScreenCount = onScreenCount + 1
                        local dx = screenX - 0.5
                        local dy = screenY - 0.5
                        local screenDistSq = dx * dx + dy * dy
                        if not nearestScreenDistSq or screenDistSq < nearestScreenDistSq then
                            nearestScreenDistSq = screenDistSq
                        end
                        if screenDistSq <= aimRadiusSq and (not bestAimScore or screenDistSq < bestAimScore) then
                            bestAimScore = screenDistSq
                            bestPoint = point
                        end
                    end
                end
            end

            if onScreenCount > 0 then
                sleep = activeSleep
            end

            local validOptions = bestPoint and GetValidOptions(bestPoint) or {}
            local canInteract = bestPoint and #validOptions > 0

            if canInteract then
                Aimed = {
                    registrationId = bestPoint.registrationId,
                    coords = bestPoint.coords,
                    entity = bestPoint.entity,
                    model = bestPoint.model,
                    distance = bestPoint.dist,
                    meta = bestPoint.meta,
                    options = validOptions,
                    entry = bestPoint.entry,
                }
            end

            local aimedOption = canInteract and validOptions[1] or nil

            for i = 1, NearbyCount do
                local point = NearbyCache[i]
                local screen = screenCache[i]
                if screen and screen.onScreen then
                    local isAimed = canInteract and point == bestPoint
                    local dict, name, quiet, aimedStyle = ResolveSprites(point.entry, isAimed and aimedOption or nil)
                    if EnsureDict(dict) then
                        local style = isAimed and aimedStyle or quiet
                        local nearDist = point.entry.interactDistance or Config.DefaultInteractDistance
                        local farDist = point.entry.distance or Config.DefaultDistance
                        local scale = GetSpriteDistanceScale(point.dist or farDist, nearDist, farDist)
                        DrawSprite(
                            dict,
                            name,
                            screen.x,
                            screen.y,
                            style.w * scale,
                            style.h * scale,
                            0.0,
                            style.r or 255,
                            style.g or 255,
                            style.b or 255,
                            style.a or 255,
                            false
                        )
                    end
                end
            end

            if showCenterDot and nearestScreenDistSq and nearestScreenDistSq <= centerDotRadiusSq then
                if EnsureDict(defaultDict) then
                    local style = canInteract and centerDotAimed or centerDotQuiet
                    local closeness = 1.0 - (math.sqrt(nearestScreenDistSq) / centerDotRadius)
                    if closeness < 0.0 then closeness = 0.0 end
                    if closeness > 1.0 then closeness = 1.0 end
                    local alpha = math.floor((style.a or 160) * (0.35 + (0.65 * closeness)))
                    DrawSprite(
                        defaultDict,
                        defaultName,
                        0.5,
                        0.5,
                        style.w,
                        style.h,
                        0.0,
                        style.r or 255,
                        style.g or 255,
                        style.b or 255,
                        alpha,
                        false
                    )
                end
            end

            if canInteract then
                SyncOptionPrompts(validOptions, bestPoint.meta)
                -- tabAmount 1 = single page with all options
                PromptSetActiveGroupThisFrame(PromptGroup, GetPromptGroupLabel(), 1, 0, 0, 0)

                for i = 1, #ActivePrompts do
                    local slot = ActivePrompts[i]
                    if IsOptionPromptCompleted(slot) then
                        local data = BuildSelectData(bestPoint, slot.option, bestPoint.dist)
                        FireOption(slot.option, data)
                        -- Rebuild prompts so hold/mash progress does not re-fire
                        ClearOptionPrompts()
                        Wait(slot.mode == "standard" and 250 or 500)
                        break
                    end
                end
            else
                if ActivePromptKey then
                    ClearOptionPrompts()
                end
            end
        else
            if ActivePromptKey then
                ClearOptionPrompts()
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler("onResourceStop", function(resource)
    local cleared = false
    for id, entry in pairs(Registry) do
        if entry.resource == resource then
            Registry[id] = nil
            cleared = true
        end
    end

    if cleared then
        IndexRegistry()
        Aimed = nil
        ClearOptionPrompts()
        NearbyCache = {}
        NearbyCount = 0
    end

    if resource == GetCurrentResourceName() then
        ClearOptionPrompts()
        for dict in pairs(LoadedDicts) do
            SetStreamedTextureDictAsNoLongerNeeded(dict)
        end
        LoadedDicts = {}
        Registry = {}
        IndexRegistry()
        Aimed = nil
        NearbyCache = {}
        NearbyCount = 0
    end
end)

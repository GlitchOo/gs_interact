-- CFX GetEntitiesInRadius entity types
local ENTITY_TYPE_PED = 1
local ENTITY_TYPE_VEHICLE = 2
local ENTITY_TYPE_OBJECT = 3

local function invokingResource()
    return GetInvokingResource() or GetCurrentResourceName()
end

local function buildModelSet(models)
    local set = {}
    if type(models) ~= "table" then
        error("gs_interact: models must be a table")
    end

    for _, model in pairs(models) do
        local hash = model
        if type(model) == "string" then
            hash = joaat(model)
        elseif type(model) == "table" and model.model then
            hash = joaat(model.model)
        end
        if type(hash) == "number" then
            set[hash] = true
        end
    end

    return set
end

local function commonTargetFields(data)
    return {
        distance = data.distance,
        interactDistance = data.interactDistance,
        SpriteDict = data.SpriteDict,
        SpriteName = data.SpriteName,
        SpriteQuiet = data.SpriteQuiet,
        SpriteAimed = data.SpriteAimed,
        SpriteZOffset = data.SpriteZOffset,
        bone = data.bone,
        requireOnFoot = data.requireOnFoot,
        meta = data.meta,
        getMeta = data.getMeta,
        options = data.options,
        enabled = data.enabled,
    }
end

local function registerModels(exportName, entityType, data)
    if type(data) ~= "table" then
        error(("gs_interact:%s expected a table"):format(exportName))
    end

    local id = data.id
    if not id then
        error(("gs_interact:%s requires data.id"):format(exportName))
    end
    if not data.models then
        error(("gs_interact:%s requires data.models"):format(exportName))
    end

    local fields = commonTargetFields(data)
    fields.type = "models"
    fields.resource = invokingResource()
    fields.entityType = entityType
    fields.models = buildModelSet(data.models)
    return GsInteract.Register(id, fields)
end

local function registerEntity(exportName, entityType, data)
    if type(data) ~= "table" then
        error(("gs_interact:%s expected a table"):format(exportName))
    end

    local id = data.id
    if not id then
        error(("gs_interact:%s requires data.id"):format(exportName))
    end
    if not data.entity or data.entity == 0 then
        error(("gs_interact:%s requires data.entity"):format(exportName))
    end

    local fields = commonTargetFields(data)
    fields.type = "entity"
    fields.resource = invokingResource()
    fields.entityType = entityType
    fields.entity = data.entity
    return GsInteract.Register(id, fields)
end

---@param data table
---@return string id
exports("addPoint", function(data)
    if type(data) ~= "table" then
        error("gs_interact:addPoint expected a table")
    end

    local id = data.id
    if not id then
        error("gs_interact:addPoint requires data.id")
    end
    if not data.coords then
        error("gs_interact:addPoint requires data.coords")
    end

    return GsInteract.Register(id, {
        type = "point",
        resource = invokingResource(),
        coords = data.coords,
        distance = data.distance,
        interactDistance = data.interactDistance,
        SpriteDict = data.SpriteDict,
        SpriteName = data.SpriteName,
        SpriteQuiet = data.SpriteQuiet,
        SpriteAimed = data.SpriteAimed,
        SpriteZOffset = data.SpriteZOffset,
        requireOnFoot = data.requireOnFoot,
        meta = data.meta,
        options = data.options,
        enabled = data.enabled,
    })
end)

---@param data table
---@return string id
exports("addModels", function(data)
    return registerModels("addModels", ENTITY_TYPE_OBJECT, data)
end)

---@param data table
---@return string id
exports("addEntity", function(data)
    return registerEntity("addEntity", ENTITY_TYPE_OBJECT, data)
end)

---@param data table
---@return string id
exports("addPedModels", function(data)
    return registerModels("addPedModels", ENTITY_TYPE_PED, data)
end)

---@param data table
---@return string id
exports("addPedEntity", function(data)
    return registerEntity("addPedEntity", ENTITY_TYPE_PED, data)
end)

---@param data table
---@return string id
exports("addWagonModels", function(data)
    return registerModels("addWagonModels", ENTITY_TYPE_VEHICLE, data)
end)

---@param data table
---@return string id
exports("addWagonEntity", function(data)
    return registerEntity("addWagonEntity", ENTITY_TYPE_VEHICLE, data)
end)

exports("remove", function(id)
    return GsInteract.Remove(id)
end)

exports("removeOption", function(id, optionName)
    return GsInteract.RemoveOption(id, optionName)
end)

exports("setEnabled", function(id, enabled)
    return GsInteract.SetEnabled(id, enabled)
end)

exports("getAimed", function()
    return GsInteract.GetAimed()
end)

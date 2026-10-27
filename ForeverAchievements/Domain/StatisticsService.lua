local _, ns = ...

-- Per-character counters (character.stats). Definitions come from Data/Statistics.lua through Register:
--   { id, category, name (locale key), kind = "counter" | "max" }
-- A counter only goes up by increments; a max keeps the highest value seen.
-- deps: store, guid (function returning the current GUID).
local Statistics = {}
Statistics.__index = Statistics

local definitions = {}
local definitionById = {}

function Statistics.Register(list)
  for _, definition in ipairs(list) do
    if not definitionById[definition.id] then
      definitions[#definitions + 1] = definition
    end
    definitionById[definition.id] = definition
  end
end

function Statistics.Definitions()
  return definitions
end

function Statistics.Definition(id)
  return definitionById[id]
end

function Statistics.New(deps)
  return setmetatable({ store = deps.store, guid = deps.guid }, Statistics)
end

function Statistics:Get(id)
  local guid = self.guid()
  if not guid then
    return 0
  end
  return self.store:Stats(guid)[id] or 0
end

-- Adds to a counter (default 1). Returns the new value, or nil plus "unknown" | "invalid" | "no_character".
function Statistics:Increment(id, amount)
  amount = amount == nil and 1 or amount
  local definition = definitionById[id]
  local guid = self.guid()
  if not definition then
    return nil, "unknown"
  elseif definition.kind ~= "counter" or type(amount) ~= "number" or amount < 0 then
    return nil, "invalid"
  elseif not guid then
    return nil, "no_character"
  end
  local stats = self.store:Stats(guid)
  stats[id] = (stats[id] or 0) + amount
  return stats[id]
end

-- Raises a max statistic when the value is higher. Returns the stored value, or nil plus the same errors.
function Statistics:SetMax(id, value)
  local definition = definitionById[id]
  local guid = self.guid()
  if not definition then
    return nil, "unknown"
  elseif definition.kind ~= "max" or type(value) ~= "number" then
    return nil, "invalid"
  elseif not guid then
    return nil, "no_character"
  end
  local stats = self.store:Stats(guid)
  stats[id] = math.max(stats[id] or 0, value)
  return stats[id]
end

-- Every definition with the current character's value, in definition order.
function Statistics:List()
  local result = {}
  for _, definition in ipairs(definitions) do
    result[#result + 1] = { definition = definition, value = self:Get(definition.id) }
  end
  return result
end

ns.StatisticsService = Statistics

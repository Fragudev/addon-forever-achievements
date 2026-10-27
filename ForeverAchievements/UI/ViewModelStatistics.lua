local _, ns = ...

-- The statistics page without frames: the definitions and the current character's values, grouped by category in
-- the order the definitions were registered.
local VM = ns.ViewModel
local L = ns.L

local Statistics = {}

-- Returns { { id, name, rows = { { id, name, value, text } } } }; nothing when there are no definitions.
function Statistics.Build(app)
  local groups, byCategory = {}, {}
  for _, item in ipairs(app.stats:List()) do
    local definition = item.definition
    local group = byCategory[definition.category]
    if not group then
      group = { id = definition.category, name = L[definition.category], rows = {} }
      byCategory[definition.category] = group
      groups[#groups + 1] = group
    end
    group.rows[#group.rows + 1] = {
      id = definition.id,
      name = L[definition.name],
      value = item.value,
      text = definition.format == "money" and VM.Money(item.value) or VM.Thousands(item.value),
    }
  end
  return groups
end

ns.ViewModelStatistics = Statistics

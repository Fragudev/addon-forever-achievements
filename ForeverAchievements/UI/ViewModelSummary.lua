local _, ns = ...

-- The summary page without frames: the five latest achievements, progress per top-level category and the total.
local VMA = ns.ViewModelAchievements

local Summary = {}

Summary.RECENT = 5

-- Every earned achievement visible in the view, newest first: { ach, state }.
local function earnedList(ctx)
  local list = {}
  for _, ach in ipairs(ctx.catalog.All()) do
    if ctx.catalog.Get(ach.id) == ach then
      local ok, state = VMA.IsVisible(ctx, ach)
      if ok and state.earned then
        list[#list + 1] = { ach = ach, state = state }
      end
    end
  end
  table.sort(list, function(a, b)
    local atA, atB = a.state.entry.at or 0, b.state.entry.at or 0
    if atA ~= atB then
      return atA > atB
    end
    return a.ach.id < b.ach.id
  end)
  return list
end

-- { points, recent = { rows }, categories = { { id, name, earned, total, fraction, text } }, overall = { earned,
-- total, fraction, text } }
function Summary.Build(ctx)
  local recent = {}
  for index, item in ipairs(earnedList(ctx)) do
    if index > Summary.RECENT then
      break
    end
    recent[#recent + 1] = VMA.Row(ctx, item.ach.id)
  end
  local categories = {}
  for _, node in ipairs(VMA.Tree(ctx)) do
    categories[#categories + 1] = {
      id = node.id,
      name = node.name,
      earned = node.earned,
      total = node.total,
      fraction = node.fraction,
      text = node.text,
    }
  end
  return { points = VMA.Points(ctx), recent = recent, categories = categories, overall = VMA.Totals(ctx) }
end

ns.ViewModelSummary = Summary

local _, ns = ...

-- Summary tab: the latest achievements, progress per category and the totals. It only paints what
-- ViewModelSummary gives it. Tabs receive (page, env): env = { app, mode, ctx, state, redraw, relayout }.
local Kit = ns.Kit
local L = ns.L
local VM = ns.ViewModel

ns.Tabs = ns.Tabs or {}

local function recentCard(page, data)
  local card = Kit.Card(page, { title = L["ui.summary.recent"], gap = 10 })
  if #data.recent == 0 then
    Kit.EmptyState(
      card,
      { icon = "trophy", title = L["ui.summary.recent_empty_title"], hint = L["ui.summary.recent_empty_hint"] }
    )
    return
  end
  local rows = {}
  for _, row in ipairs(data.recent) do
    rows[#rows + 1] = {
      status = "met",
      title = row.name,
      subtitle = row.dateText,
      value = row.pointsText ~= "" and string.format(L["ui.points_short"], row.pointsText) or L["ui.feat"],
      valueColor = "gold",
    }
  end
  Kit.List(card, { rows = rows })
end

local function categoriesCard(page, data)
  local card = Kit.Card(page, { title = L["ui.summary.categories"], gap = 12 })
  for _, category in ipairs(data.categories) do
    local line = Kit.Row(card, { gap = 10, align = "center" })
    Kit.Label(line, { text = category.name, layout = { weight = 1 } })
    Kit.Label(line, { text = category.text, style = "small", color = "dim", layout = { width = "auto" } })
    Kit.ProgressBar(card, { value = category.fraction, color = "accent", height = 6, layout = { gap = 4 } })
  end
end

ns.Tabs.summary = {
  Draw = function(page, env)
    local data = ns.ViewModelSummary.Build(env.ctx)
    Kit.PageHeader(page, {
      title = L["ui.summary.title"],
      description = env.mode == "account" and L["ui.summary.desc_account"] or L["ui.summary.desc_character"],
    })
    Kit.StatGrid(page, {
      columns = 3,
      stats = {
        { caption = L["ui.summary.points"], value = VM.Thousands(data.points), color = "gold" },
        { caption = L["ui.summary.overall"], value = data.overall.text },
        { caption = L["ui.nav.achievements"], value = string.format("%d%%", math.floor(data.overall.fraction * 100)) },
      },
    })
    Kit.ProgressBar(page, { value = data.overall.fraction, color = "success", height = 8 })
    recentCard(page, data)
    categoriesCard(page, data)
  end,
}

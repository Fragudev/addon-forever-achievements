local _, ns = ...

-- Statistics tab: the counters of the current character, grouped by category.
local Kit = ns.Kit
local L = ns.L

ns.Tabs = ns.Tabs or {}

ns.Tabs.statistics = {
  Draw = function(page, env)
    Kit.PageHeader(page, { title = L["ui.stats.title"], description = L["ui.stats.desc"] })
    local groups = ns.ViewModelStatistics.Build(env.app)
    if #groups == 0 then
      Kit.EmptyState(page, { icon = "chart", title = L["ui.stats.empty_title"], hint = L["ui.stats.empty_hint"] })
      return
    end
    for _, group in ipairs(groups) do
      local card = Kit.Card(page, { title = group.name, gap = 4 })
      for _, row in ipairs(group.rows) do
        Kit.KeyValue(card, { label = row.name, value = row.text })
      end
    end
  end,
}

local _, ns = ...

-- Statistic definitions. kind = "counter" (only goes up by increments) | "max" (keeps the highest value seen).
-- Only a few entries for now; later phases extend the list.
ns.StatisticsService.Register({
  { id = "deaths", category = "stat.cat.general", name = "stat.deaths", kind = "counter" },
  { id = "quests_completed", category = "stat.cat.general", name = "stat.quests_completed", kind = "counter" },
  { id = "highest_level", category = "stat.cat.general", name = "stat.highest_level", kind = "max" },
})

local _, ns = ...

-- Statistic definitions. kind = "counter" (only goes up by increments) | "max" (keeps the highest value seen).
-- format = "money" shows a copper value as gold, silver and copper. Categories (locale key stat.cat.*) are listed in
-- the order of their first definition. Domain/StatisticsWiring.lua maps the facts of the detectors onto these ids.
local bgs = {
  { id = 489, key = "489" },
  { id = 529, key = "529" },
  { id = 30, key = "30" },
}

local definitions = {
  -- General.
  { id = "deaths", category = "stat.cat.general", name = "stat.deaths", kind = "counter" },
  { id = "quests_completed", category = "stat.cat.general", name = "stat.quests_completed", kind = "counter" },
  { id = "highest_level", category = "stat.cat.general", name = "stat.highest_level", kind = "max" },
  { id = "emotes_used", category = "stat.cat.general", name = "stat.emotes_used", kind = "counter" },

  -- Combat.
  { id = "bosses_killed", category = "stat.cat.combat", name = "stat.bosses_killed", kind = "counter" },
  { id = "dungeon_bosses", category = "stat.cat.combat", name = "stat.dungeon_bosses", kind = "counter" },
  { id = "raid_bosses", category = "stat.cat.combat", name = "stat.raid_bosses", kind = "counter" },

  -- PvP.
  { id = "honorable_kills", category = "stat.cat.pvp", name = "stat.honorable_kills", kind = "max" },
  { id = "bg_played", category = "stat.cat.pvp", name = "stat.bg_played", kind = "counter" },
  { id = "bg_won", category = "stat.cat.pvp", name = "stat.bg_won", kind = "counter" },
}
for _, bg in ipairs(bgs) do
  definitions[#definitions + 1] =
    { id = "bg_played_" .. bg.key, category = "stat.cat.pvp", name = "stat.bg_played_" .. bg.key, kind = "counter" }
  definitions[#definitions + 1] =
    { id = "bg_won_" .. bg.key, category = "stat.cat.pvp", name = "stat.bg_won_" .. bg.key, kind = "counter" }
end

-- Wealth and collections.
definitions[#definitions + 1] =
  { id = "gold_looted", category = "stat.cat.wealth", name = "stat.gold_looted", kind = "counter", format = "money" }
definitions[#definitions + 1] =
  { id = "epic_equipped", category = "stat.cat.collections", name = "stat.epic_equipped", kind = "max" }
definitions[#definitions + 1] = { id = "mounts", category = "stat.cat.collections", name = "stat.mounts", kind = "max" }

ns.StatisticsService.Register(definitions)

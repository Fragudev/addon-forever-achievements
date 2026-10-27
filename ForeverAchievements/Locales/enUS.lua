local _, ns = ...

-- UI strings (English, the fallback for every locale). Keep the placeholders (%d, %s) in the same order in esES.
ns.Locale.Register("enUS", {
  -- Categories (Data/Categories.lua)
  ["cat.general"] = "General",
  ["cat.general.level"] = "Level",
  ["cat.general.wealth"] = "Wealth",
  ["cat.general.time"] = "Time played",
  ["cat.general.misc"] = "Miscellaneous",
  ["cat.general.collections"] = "Collections",
  ["cat.general.emotes"] = "Emotes",
  ["cat.quests"] = "Quests",
  ["cat.quests.kalimdor"] = "Kalimdor",
  ["cat.quests.eastern_kingdoms"] = "Eastern Kingdoms",
  ["cat.quests.total"] = "Quests completed",
  ["cat.exploration"] = "Exploration",
  ["cat.exploration.kalimdor"] = "Kalimdor",
  ["cat.exploration.eastern_kingdoms"] = "Eastern Kingdoms",
  ["cat.pvp"] = "Player vs. Player",
  ["cat.pvp.honor"] = "Honor",
  ["cat.pvp.battlegrounds"] = "Battlegrounds",
  ["cat.dungeons"] = "Dungeons & Raids",
  ["cat.dungeons.five"] = "Dungeons",
  ["cat.dungeons.raids"] = "Raids",
  ["cat.professions"] = "Professions",
  ["cat.professions.primary"] = "Primary professions",
  ["cat.professions.secondary"] = "Secondary professions",
  ["cat.reputation"] = "Reputation",
  ["cat.reputation.factions"] = "Factions",
  ["cat.reputation.capitals"] = "Capital cities",
  ["cat.reputation.world"] = "World factions",
  ["cat.reputation.pvp"] = "Battleground factions",
  ["cat.feats"] = "Feats of Strength",
  ["cat.feats.general"] = "General",
  ["cat.account"] = "Account",
  ["cat.account.general"] = "General",

  -- Achievement list and messages
  ["ui.earned_before_addon"] = "Earned before the addon",
  ["retro.summary"] = "Granted %d achievements earned before the addon",
  ["retro.summary.one"] = "Granted 1 achievement earned before the addon",

  -- Statistics (Data/Statistics.lua)
  ["stat.cat.general"] = "General",
  ["stat.deaths"] = "Total deaths",
  ["stat.quests_completed"] = "Quests completed",
  ["stat.highest_level"] = "Highest level reached",
})

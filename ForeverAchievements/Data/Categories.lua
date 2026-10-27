local _, ns = ...

-- Category tree (plan section 7). `name` is a locale key (Locales/enUS.lua). Achievements use the leaf id.
ns.Catalog.RegisterCategories({
  {
    id = "general",
    name = "cat.general",
    children = {
      { id = "general.level", name = "cat.general.level" },
      { id = "general.wealth", name = "cat.general.wealth" },
      { id = "general.time", name = "cat.general.time" },
      { id = "general.collections", name = "cat.general.collections" },
      { id = "general.emotes", name = "cat.general.emotes" },
      { id = "general.misc", name = "cat.general.misc" },
    },
  },
  {
    id = "quests",
    name = "cat.quests",
    children = {
      { id = "quests.kalimdor", name = "cat.quests.kalimdor" },
      { id = "quests.eastern_kingdoms", name = "cat.quests.eastern_kingdoms" },
      { id = "quests.total", name = "cat.quests.total" },
    },
  },
  {
    id = "exploration",
    name = "cat.exploration",
    children = {
      { id = "exploration.kalimdor", name = "cat.exploration.kalimdor" },
      { id = "exploration.eastern_kingdoms", name = "cat.exploration.eastern_kingdoms" },
    },
  },
  {
    id = "pvp",
    name = "cat.pvp",
    children = {
      { id = "pvp.honor", name = "cat.pvp.honor" },
      { id = "pvp.battlegrounds", name = "cat.pvp.battlegrounds" },
    },
  },
  {
    id = "dungeons",
    name = "cat.dungeons",
    children = {
      { id = "dungeons.five", name = "cat.dungeons.five" },
      { id = "dungeons.raids", name = "cat.dungeons.raids" },
    },
  },
  {
    id = "professions",
    name = "cat.professions",
    children = {
      { id = "professions.primary", name = "cat.professions.primary" },
      { id = "professions.secondary", name = "cat.professions.secondary" },
    },
  },
  {
    id = "reputation",
    name = "cat.reputation",
    children = {
      { id = "reputation.factions", name = "cat.reputation.factions" },
      { id = "reputation.capitals", name = "cat.reputation.capitals" },
      { id = "reputation.world", name = "cat.reputation.world" },
      { id = "reputation.pvp", name = "cat.reputation.pvp" },
    },
  },
  {
    id = "feats",
    name = "cat.feats",
    children = {
      { id = "feats.general", name = "cat.feats.general" },
    },
  },
  {
    id = "account",
    name = "cat.account",
    children = {
      { id = "account.general", name = "cat.account.general" },
    },
  },
})

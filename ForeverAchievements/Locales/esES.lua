local _, ns = ...

-- UI strings (Spanish, neutral register; also used by esMX).
ns.Locale.Register("esES", {
  -- Categories (Data/Categories.lua)
  ["cat.general"] = "General",
  ["cat.general.level"] = "Nivel",
  ["cat.general.wealth"] = "Riqueza",
  ["cat.general.time"] = "Tiempo de juego",
  ["cat.general.misc"] = "Varios",
  ["cat.quests"] = "Misiones",
  ["cat.quests.kalimdor"] = "Kalimdor",
  ["cat.quests.eastern_kingdoms"] = "Reinos del Este",
  ["cat.quests.total"] = "Misiones completadas",
  ["cat.exploration"] = "Exploración",
  ["cat.exploration.kalimdor"] = "Kalimdor",
  ["cat.exploration.eastern_kingdoms"] = "Reinos del Este",
  ["cat.pvp"] = "Jugador contra jugador",
  ["cat.pvp.honor"] = "Honor",
  ["cat.pvp.battlegrounds"] = "Campos de batalla",
  ["cat.dungeons"] = "Mazmorras y bandas",
  ["cat.dungeons.five"] = "Mazmorras",
  ["cat.dungeons.raids"] = "Bandas",
  ["cat.professions"] = "Profesiones",
  ["cat.professions.primary"] = "Profesiones principales",
  ["cat.professions.secondary"] = "Profesiones secundarias",
  ["cat.reputation"] = "Reputación",
  ["cat.reputation.factions"] = "Facciones",
  ["cat.feats"] = "Proezas de fuerza",
  ["cat.feats.general"] = "General",
  ["cat.account"] = "Cuenta",
  ["cat.account.general"] = "General",

  -- Achievement list and messages
  ["ui.earned_before_addon"] = "Anterior al addon",
  ["retro.summary"] = "Se concedieron %d logros anteriores al addon",
  ["retro.summary.one"] = "Se concedió 1 logro anterior al addon",

  -- Statistics (Data/Statistics.lua)
  ["stat.cat.general"] = "General",
  ["stat.deaths"] = "Muertes totales",
  ["stat.quests_completed"] = "Misiones completadas",
  ["stat.highest_level"] = "Nivel más alto alcanzado",
})

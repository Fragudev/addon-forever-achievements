-- Loads addon files into a fresh namespace the way the client does: loadfile(path)(addonName, ns).
local Loader = {}

local ROOT = "ForeverAchievements/"
local ADDON = "ForeverAchievements"

Loader.CORE = {
  "Core/Constants.lua",
  "Core/Locale.lua",
  "Locales/enUS.lua",
  "Locales/esES.lua",
  "Core/EventBus.lua",
  "Core/Store.lua",
}

Loader.DOMAIN = {
  "Domain/Catalog.lua",
  "Domain/CriteriaEngine.lua",
  "Domain/AwardService.lua",
  "Domain/AccountService.lua",
  "Domain/RetroScan.lua",
  "Domain/StatisticsService.lua",
  "Domain/Settings.lua",
  "Domain/TrackerService.lua",
}

Loader.DATA = {
  "Locales/Achievements_enUS.lua",
  "Locales/Achievements_esES.lua",
  "Locales/Achievements/Quests_enUS.lua",
  "Locales/Achievements/Quests_esES.lua",
  "Locales/Achievements/Exploration_enUS.lua",
  "Locales/Achievements/Exploration_esES.lua",
  "Locales/Achievements/Reputation_enUS.lua",
  "Locales/Achievements/Reputation_esES.lua",
  "Locales/Achievements/Professions_enUS.lua",
  "Locales/Achievements/Professions_esES.lua",
  "Locales/Achievements/DungeonsRaids_enUS.lua",
  "Locales/Achievements/DungeonsRaids_esES.lua",
  "Locales/Achievements/PvP_enUS.lua",
  "Locales/Achievements/PvP_esES.lua",
  "Locales/Achievements/Account_enUS.lua",
  "Locales/Achievements/Account_esES.lua",
  "Data/Categories.lua",
  "Data/Statistics.lua",
  "Data/Reference/Encounters.lua",
  "Data/Reference/Zones.lua",
  "Data/Reference/Factions.lua",
  "Data/Reference/SkillLines.lua",
  "Data/Reference/Battlegrounds.lua",
  "Data/Reference/Quests.lua",
  "Data/Reference/Items.lua",
  "Data/Reference/Critters.lua",
  "Data/Achievements/General.lua",
  "Data/Achievements/Quests.lua",
  "Data/Achievements/Exploration.lua",
  "Data/Achievements/Reputation.lua",
  "Data/Achievements/Professions.lua",
  "Data/Achievements/DungeonsRaids.lua",
  "Data/Achievements/PvP.lua",
  "Data/Achievements/Account.lua",
}

-- Achievement locales, reference tables and data, in load order (no categories or statistics).
Loader.CATALOG_FILES = {
  "Locales/Achievements_enUS.lua",
  "Locales/Achievements_esES.lua",
  "Locales/Achievements/Quests_enUS.lua",
  "Locales/Achievements/Quests_esES.lua",
  "Locales/Achievements/Exploration_enUS.lua",
  "Locales/Achievements/Exploration_esES.lua",
  "Locales/Achievements/Reputation_enUS.lua",
  "Locales/Achievements/Reputation_esES.lua",
  "Locales/Achievements/Professions_enUS.lua",
  "Locales/Achievements/Professions_esES.lua",
  "Locales/Achievements/DungeonsRaids_enUS.lua",
  "Locales/Achievements/DungeonsRaids_esES.lua",
  "Locales/Achievements/PvP_enUS.lua",
  "Locales/Achievements/PvP_esES.lua",
  "Locales/Achievements/Account_enUS.lua",
  "Locales/Achievements/Account_esES.lua",
  "Data/Reference/Encounters.lua",
  "Data/Reference/Zones.lua",
  "Data/Reference/Factions.lua",
  "Data/Reference/SkillLines.lua",
  "Data/Reference/Battlegrounds.lua",
  "Data/Reference/Quests.lua",
  "Data/Reference/Items.lua",
  "Data/Reference/Critters.lua",
  "Data/Achievements/General.lua",
  "Data/Achievements/Quests.lua",
  "Data/Achievements/Exploration.lua",
  "Data/Achievements/Reputation.lua",
  "Data/Achievements/Professions.lua",
  "Data/Achievements/DungeonsRaids.lua",
  "Data/Achievements/PvP.lua",
  "Data/Achievements/Account.lua",
}

-- The UI block of the TOC, in load order (kit first, then view models).
Loader.UI_LOCALES = { "Locales/UI_enUS.lua", "Locales/UI_esES.lua" }

function Loader.Load(...)
  local ns = {}
  for _, files in ipairs({ ... }) do
    for _, file in ipairs(files) do
      assert(loadfile(ROOT .. file))(ADDON, ns)
    end
  end
  return ns
end

function Loader.Full()
  return Loader.Load(Loader.CORE, Loader.DOMAIN, Loader.DATA, Loader.UI_LOCALES)
end

return Loader

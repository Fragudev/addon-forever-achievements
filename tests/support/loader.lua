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
}

Loader.DATA = {
  "Locales/Achievements_enUS.lua",
  "Locales/Achievements_esES.lua",
  "Data/Categories.lua",
  "Data/Achievements/General.lua",
}

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
  return Loader.Load(Loader.CORE, Loader.DOMAIN, Loader.DATA)
end

return Loader

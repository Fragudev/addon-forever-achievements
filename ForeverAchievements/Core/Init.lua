local addonName, ns = ...

local Constants = ns.Constants
local PREFIX = "|cff33ff99Forever Achievements|r"

function ns.GetVersion()
  local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
  if not version or version == "@project-version@" then
    return "dev"
  end
  return version
end

local function InitDatabase()
  ForeverAchievementsDB = ForeverAchievementsDB or { schema = Constants.SCHEMA_VERSION }
  ns.db = ForeverAchievementsDB
end

local function Say(message)
  print(PREFIX .. " " .. message)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, loadedAddon)
  if event == "ADDON_LOADED" then
    if loadedAddon == addonName then
      InitDatabase()
    end
  elseif event == "PLAYER_LOGIN" then
    Say(ns.GetVersion() .. " loaded")
  end
end)

local addonName, ns = ...

local PREFIX = "|cff33ff99Forever Achievements|r"

function ns.GetVersion()
  local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
  if not version or version == "@project-version@" then
    return "dev"
  end
  return version
end

local function Say(message)
  print(PREFIX .. " " .. message)
end

local function Now()
  return ns.Platform.GetServerTime() or (os and os.time and os.time()) or 0
end

-- Opens the saved variable. A db written by a newer addon is left untouched and the addon stays disabled.
local function InitDatabase()
  local store, reason = ns.Store.Open(ForeverAchievementsDB, { now = Now })
  if not store then
    ns.disabled = reason
    local schema = type(ForeverAchievementsDB) == "table" and ForeverAchievementsDB.schema or 0
    Say(string.format(ns.L["app.schema_newer"], schema))
    return
  end
  ForeverAchievementsDB = store:Db()
  ns.db = ForeverAchievementsDB
  ns.store = store
end

local function StartApp()
  if ns.disabled or not ns.store then
    return
  end
  local ok, err = pcall(function()
    ns.App = ns.AppBuilder.Build({ store = ns.store })
    ns.App:Start()
  end)
  if not ok then
    Say(string.format(ns.L["app.start_failed"], tostring(err)))
  end
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
    if not ns.disabled then
      Say(ns.GetVersion() .. " loaded")
    end
    StartApp()
  end
end)

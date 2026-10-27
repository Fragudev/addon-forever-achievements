-- A wired app (real services over the test catalog) with Platform and the detectors loaded, a fake client, a manual
-- timer queue and recorded frames. Each spec builds one in before_each and closes it in after_each.
local Harness = dofile("tests/support/harness.lua")

local ROOT = "ForeverAchievements/"
local ADDON = "ForeverAchievements"

local DETECTOR_FILES = {
  Level = "Detectors/Level.lua",
  Money = "Detectors/Money.lua",
  Played = "Detectors/Played.lua",
  Quests = "Detectors/Quests.lua",
  Exploration = "Detectors/Exploration.lua",
  Reputation = "Detectors/Reputation.lua",
  Skills = "Detectors/Skills.lua",
  Collections = "Detectors/Collections.lua",
  PvP = "Detectors/PvP.lua",
  Encounters = "Detectors/Encounters.lua",
  Battlegrounds = "Detectors/Battlegrounds.lua",
  Deaths = "Detectors/Deaths.lua",
  Snapshot = "Detectors/Snapshot.lua",
}

-- Client globals the specs define; all of them are removed between specs.
local CLIENT_GLOBALS = {
  "UnitLevel",
  "UnitGUID",
  "UnitName",
  "GetUnitName",
  "UnitClass",
  "UnitRace",
  "UnitFactionGroup",
  "GetMoney",
  "RequestTimePlayed",
  "C_QuestLog",
  "C_Map",
  "C_MapExplorationInfo",
  "C_Reputation",
  "GetFactionInfoByID",
  "GetFactionInfo",
  "GetNumFactions",
  "GetProfessions",
  "GetProfessionInfo",
  "C_MountJournal",
  "C_PetJournal",
  "C_ToyBox",
  "GetPVPLifetimeStats",
  "GetServerTime",
  "GetBattlefieldWinner",
  "IsInInstance",
  "GetInstanceInfo",
  "IsEncounterInProgress",
  "C_ChatInfo",
  "GetTime",
  "DoEmote",
  "GetItemCount",
  "GetInventoryItemLink",
  "GetInventoryItemQuality",
  "C_Item",
  "GOLD_AMOUNT",
  "SILVER_AMOUNT",
  "COPPER_AMOUNT",
  "YOU_LOOT_MONEY",
  "LOOT_MONEY_SPLIT",
  "C_Timer",
  "issecretvalue",
}

local Env = {}

function Env.Build(extraFiles)
  for _, name in ipairs(CLIENT_GLOBALS) do
    _G[name] = nil
  end

  local h = Harness.Build()
  local ns = h.ns
  local files = {
    "Core/Platform.lua",
    "Locales/Detectors_enUS.lua",
    "Locales/Detectors_esES.lua",
    "Detectors/Detector.lua",
  }
  for _, file in ipairs(files) do
    assert(loadfile(ROOT .. file))(ADDON, ns)
  end
  for _, file in pairs(DETECTOR_FILES) do
    assert(loadfile(ROOT .. file))(ADDON, ns)
  end
  for _, file in ipairs(extraFiles or {}) do
    assert(loadfile(ROOT .. file))(ADDON, ns)
  end
  assert(loadfile(ROOT .. "Core/App.lua"))(ADDON, ns)

  local env = { ns = ns, h = h, frames = {}, timers = {}, refuse = {}, said = {}, realCreateFrame = _G.CreateFrame }

  _G.CreateFrame = function()
    local frame = env.realCreateFrame()
    function frame:RegisterEvent(event)
      if env.refuse[event] then
        error("unknown event " .. event)
      end
      self.events[event] = true
    end
    env.frames[#env.frames + 1] = frame
    return frame
  end

  env.app = ns.AppBuilder.Build({
    store = h.store,
    now = function()
      return h.time
    end,
    guid = function()
      return h.guid
    end,
    detectors = {},
    slash = false,
    say = function(message)
      env.said[#env.said + 1] = message
    end,
  })

  -- Creates a detector and registers it in the app, as App.Build does.
  function env.add(name)
    local detector = ns.Detectors[name].New(env.app)
    env.app.detectors[name] = detector
    env.app.detectorList[#env.app.detectorList + 1] = detector
    return detector
  end

  -- Installs a manual C_Timer: callbacks wait until env.flush().
  function env.useTimer()
    _G.C_Timer = {
      After = function(seconds, fn)
        env.timers[#env.timers + 1] = { seconds = seconds, fn = fn }
      end,
    }
  end

  function env.flush()
    local due = env.timers
    env.timers = {}
    for _, timer in ipairs(due) do
      timer.fn()
    end
    return #due
  end

  -- Fires an event on the (only or given) frame of a started detector.
  function env.fire(detector, event, ...)
    detector.frame.scripts.OnEvent(detector.frame, event, ...)
  end

  function env.close()
    _G.CreateFrame = env.realCreateFrame
    for _, name in ipairs(CLIENT_GLOBALS) do
      _G[name] = nil
    end
  end

  return env
end

return Env

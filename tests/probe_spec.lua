local ADDON = "ForeverAchievements"

local FAKE_GLOBALS = {
  "UnitLevel",
  "UnitGUID",
  "GetBuildInfo",
  "C_QuestLog",
  "C_Map",
  "C_MapExplorationInfo",
  "GetProfessions",
  "GetProfessionInfo",
  "GetNumCompletedAchievements",
  "GetCategoryList",
  "GetTotalAchievementPoints",
  "GetAchievementInfo",
  "C_AchievementInfo",
  "DoEmote",
  "GetItemCount",
  "RequestTimePlayed",
}

local function joined(lines)
  return table.concat(lines, "\n")
end

describe("Probe", function()
  local ns, P, bootFrame, frames

  local function load()
    frames = {}
    local realCreate = _G.CreateFrame
    _G.CreateFrame = function(...)
      local frame = realCreate(...)
      frames[#frames + 1] = frame
      return frame
    end
    ns = {}
    assert(loadfile("ForeverAchievements/Core/Constants.lua"))(ADDON, ns)
    assert(loadfile("ForeverAchievements/Core/Platform.lua"))(ADDON, ns)
    assert(loadfile("ForeverAchievements/Core/Probe.lua"))(ADDON, ns)
    _G.CreateFrame = realCreate
    P = ns.Probe
    bootFrame = frames[1]
  end

  before_each(function()
    for _, name in ipairs(FAKE_GLOBALS) do
      _G[name] = nil
    end
    _G.__hooks = nil
    load()
  end)

  after_each(function()
    for _, name in ipairs(FAKE_GLOBALS) do
      _G[name] = nil
    end
  end)

  describe("probe report", function()
    it("marks a missing API as missing and never raises", function()
      local text = joined(P.Run())
      assert.is_truthy(text:find("UnitLevel(player)=missing", 1, true) or text:find("UnitLevel=missing", 1, true))
      assert.is_truthy(text:find("native_achievements=absent", 1, true))
      assert.is_truthy(text:find("C_AchievementInfo=missing", 1, true))
    end)

    it("prints errors and secret values", function()
      _G.UnitLevel = function()
        error("boom")
      end
      _G.issecretvalue = function(value)
        return value == "secret-guid"
      end
      _G.UnitGUID = function()
        return "secret-guid"
      end
      local text = joined(P.Run())
      assert.is_truthy(text:find("error: ", 1, true))
      assert.is_truthy(text:find("boom", 1, true))
      assert.is_truthy(text:find("<secret>", 1, true))
      _G.issecretvalue = nil
    end)

    it("summarises large results", function()
      _G.C_QuestLog = {
        GetAllCompletedQuestIDs = function()
          local ids = {}
          for index = 1, 500 do
            ids[index] = 1000 + index
          end
          return ids
        end,
        IsQuestFlaggedCompleted = function()
          return true
        end,
      }
      local text = joined(P.Run())
      assert.is_truthy(text:find("table n=500 first5=1001,1002,1003,1004,1005", 1, true))
      assert.is_truthy(text:find("IsQuestFlaggedCompleted(1001)=true", 1, true))
    end)

    it("chains map results and reports table fields", function()
      _G.C_Map = {
        GetBestMapForUnit = function()
          return 1453
        end,
        GetMapInfo = function()
          return { name = "Stormwind", mapType = 3 }
        end,
        GetPlayerMapPosition = function()
          return CreateVector2D(0.5, 0.5)
        end,
      }
      _G.C_MapExplorationInfo = {
        GetExploredAreaIDsAtPosition = function()
          return {}
        end,
        GetExploredMapTextures = function()
          return nil
        end,
      }
      _G.GetProfessions = function()
        return nil, 2
      end
      _G.GetProfessionInfo = function()
        return "Mining"
      end
      local text = joined(P.Run())
      assert.is_truthy(text:find("table {mapType=3 name=Stormwind}", 1, true))
      assert.is_truthy(text:find("GetExploredAreaIDsAtPosition(1453,table)=table empty", 1, true))
      assert.is_truthy(text:find("GetProfessionInfo(2)=Mining", 1, true))
      assert.is_truthy(text:find("GetExploredMapTextures(1453)=nil", 1, true))
    end)

    it("skips items that need an earlier result", function()
      assert.is_truthy(joined(P.Run()):find("skipped", 1, true))
    end)

    it("reports the native achievement system", function()
      _G.GetCategoryList = function()
        return { 92, 96 }
      end
      _G.GetTotalAchievementPoints = function()
        return 10
      end
      _G.GetNumCompletedAchievements = function()
        return 3, 900
      end
      _G.GetAchievementInfo = function()
        return 6, "Level 10"
      end
      _G.C_AchievementInfo = { IsValidAchievement = function() end, other = 1 }
      local text = joined(P.Run())
      assert.is_truthy(text:find("native_achievements=present categories=2 points=10 completed=3", 1, true))
      assert.is_truthy(text:find("C_AchievementInfo=present functions=1 IsValidAchievement", 1, true))
      assert.is_truthy(text:find("GetAchievementInfo(6)=6, Level 10", 1, true))
    end)

    it("prints the interface number and the hook state", function()
      _G.GetBuildInfo = function()
        return "1.60.1", "123", "Jan 1 2026", 16001
      end
      _G.DoEmote = function() end
      local lines = P.Run()
      assert.is_truthy(lines[1]:find("interface=16001", 1, true))
      assert.is_truthy(joined(lines):find("DoEmote=true hooked=false", 1, true))
    end)

    it("keeps a bounded copy in the saved variables", function()
      ns.db = {}
      P.Run()
      assert.is_true(#ns.db.debug.lastProbe > 20)
      assert.is_true(#ns.db.debug.lastProbe <= 200)
    end)

    it("shows the registration summary once started", function()
      _G.DoEmote = function() end
      P.Start()
      assert.is_truthy(joined(P.Run()):find("events registered=18 refused=0", 1, true))
    end)

    it("describes a throwing item as an error", function()
      table.insert(P.ITEMS, {
        api = "Exploding",
        question = "q",
        run = function()
          error("kaboom")
        end,
      })
      assert.is_truthy(joined(P.Run()):find("Exploding=error: ", 1, true))
      table.remove(P.ITEMS)
    end)
  end)

  describe("event log", function()
    it("starts on PLAYER_LOGIN and registers every probe event", function()
      assert.is_true(bootFrame.events.PLAYER_LOGIN)
      bootFrame.scripts.OnEvent(bootFrame, "PLAYER_LOGIN")
      local registration = P.registration
      assert.are.equal(#P.EVENTS, #registration.registered)
      assert.are.equal(0, #registration.refused)
    end)

    it("never lists the combat log", function()
      for _, event in ipairs(P.EVENTS) do
        assert.are_not.equal("COMBAT_LOG_EVENT_UNFILTERED", event)
      end
    end)

    it("starts only once", function()
      local first = P.Start()
      assert.are.equal(first, P.Start())
    end)

    it("counts events and keeps the last arguments", function()
      P.Start()
      local frame = P.frame
      frame.scripts.OnEvent(frame, "ENCOUNTER_START", 1234, "Ragnaros", 14, 40)
      frame.scripts.OnEvent(frame, "ENCOUNTER_END", 1234, "Ragnaros", 14, 40, 1)
      frame.scripts.OnEvent(frame, "ENCOUNTER_END", 1234, "Ragnaros", 14, 40, 0)
      frame.scripts.OnEvent(frame, "PLAYER_DEAD")
      assert.are.equal(2, P.log.ENCOUNTER_END.count)
      assert.are.equal("1234,Ragnaros,14,40,0", P.log.ENCOUNTER_END.last)
      assert.are.equal("-", P.log.PLAYER_DEAD.last)
      local text = joined(P.EventLines())
      assert.is_truthy(text:find("ENCOUNTER_END registered=yes count=2 last=1234,Ragnaros,14,40,0", 1, true))
      assert.is_truthy(text:find("PLAYER_LEVEL_UP registered=yes count=0 last=-", 1, true))
    end)

    it("logs secret arguments without raising", function()
      _G.issecretvalue = function(value)
        return value == "hidden"
      end
      P.Start()
      P.frame.scripts.OnEvent(P.frame, "CHAT_MSG_MONEY", "hidden", 5)
      assert.are.equal("<secret>,5", P.log.CHAT_MSG_MONEY.last)
      _G.issecretvalue = nil
    end)

    it("bounds the text and the number of events", function()
      P.Record("LONG", string.rep("x", 500))
      assert.is_true(#P.log.LONG.last <= 160)
      for index = 1, 100 do
        P.Record("EVENT_" .. index)
      end
      assert.is_true(#P.logOrder <= 64)
      assert.is_nil(P.log.EVENT_100)
      P.Record("EVENT_1")
      assert.are.equal(2, P.log.EVENT_1.count)
    end)

    it("records a DoEmote hook and shows table arguments", function()
      _G.DoEmote = function() end
      P.Start()
      assert.is_true(P.hooked)
      _G.__hooks.DoEmote("WAVE", "target")
      _G.__hooks.DoEmote("LOL", {})
      assert.are.equal(2, P.log["hook:DoEmote"].count)
      assert.are.equal("LOL,table empty", P.log["hook:DoEmote"].last)
      assert.is_truthy(joined(P.EventLines()):find("hook:DoEmote installed=true count=2", 1, true))
    end)

    it("reports refused events as registered=no", function()
      local realCreate = _G.CreateFrame
      _G.CreateFrame = function(...)
        local frame = realCreate(...)
        frame.RegisterEvent = function(self, event)
          if event == "NEW_MOUNT_ADDED" then
            error("unknown event")
          end
          self.events[event] = true
        end
        return frame
      end
      P.Start()
      _G.CreateFrame = realCreate
      assert.are.same({ "NEW_MOUNT_ADDED" }, P.registration.refused)
      assert.is_truthy(joined(P.EventLines()):find("NEW_MOUNT_ADDED registered=no", 1, true))
      assert.is_truthy(joined(P.Run()):find("refused_list=NEW_MOUNT_ADDED", 1, true))
    end)

    it("says so when events were not started", function()
      assert.is_truthy(P.EventLines()[1]:find("not started", 1, true))
      assert.is_truthy(joined(P.Run()):find("events not started", 1, true))
    end)

    it("persists the event log at PLAYER_LOGOUT", function()
      ns.db = {}
      P.Start()
      P.frame.scripts.OnEvent(P.frame, "PLAYER_DEAD")
      P.frame.scripts.OnEvent(P.frame, "PLAYER_LOGOUT")
      assert.are.equal(1, ns.db.debug.probeEvents.PLAYER_DEAD.count)
    end)

    it("does not persist without a database", function()
      assert.is_false(P.Persist())
      P.Start()
      P.frame.scripts.OnEvent(P.frame, "PLAYER_LOGOUT")
    end)
  end)

  describe("selftest", function()
    it("reports each API as OK or missing", function()
      _G.UnitLevel = function() end
      local lines = P.SelfTest()
      assert.is_truthy(lines[1]:find("selftest 1/", 1, true) or lines[1]:find("selftest 2/", 1, true))
      local text = joined(lines)
      assert.is_truthy(text:find("OK      UnitLevel", 1, true))
      assert.is_truthy(text:find("missing UnitGUID", 1, true))
      assert.is_truthy(text:find("C_Reputation.GetFactionDataByID | GetFactionInfoByID", 1, true))
      assert.is_truthy(text:find("events not started", 1, true))
    end)

    it("counts an alternative as satisfying its group and shows the event summary", function()
      _G.GetFactionInfoByID = function() end
      P.Start()
      local text = joined(P.SelfTest())
      assert.is_truthy(text:find("OK      C_Reputation.GetFactionDataByID | GetFactionInfoByID", 1, true))
      assert.is_truthy(text:find("events registered=18 refused=0", 1, true))
      _G.GetFactionInfoByID = nil
    end)
  end)
end)

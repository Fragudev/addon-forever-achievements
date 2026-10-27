local ADDON = "ForeverAchievements"

local CLIENT = {
  "GetUnitName",
  "UnitName",
  "C_Reputation",
  "GetFactionInfo",
  "C_MountJournal",
  "C_Timer",
  "C_QuestLog",
  "issecretvalue",
}

describe("Platform wrappers used by the detectors", function()
  local P, realCreateFrame

  before_each(function()
    for _, name in ipairs(CLIENT) do
      _G[name] = nil
    end
    realCreateFrame = _G.CreateFrame
    local ns = {}
    assert(loadfile("ForeverAchievements/Core/Platform.lua"))(ADDON, ns)
    P = ns.Platform
  end)

  after_each(function()
    _G.CreateFrame = realCreateFrame
    for _, name in ipairs(CLIENT) do
      _G[name] = nil
    end
  end)

  describe("ReadCompletedQuestIDs", function()
    it("gives the list, even an empty one", function()
      _G.C_QuestLog = {
        GetAllCompletedQuestIDs = function()
          return {}
        end,
      }
      assert.are.same({}, P.ReadCompletedQuestIDs())
    end)

    it("gives nil when the API is missing, raises or answers a secret", function()
      assert.is_nil(P.ReadCompletedQuestIDs())
      _G.C_QuestLog = {
        GetAllCompletedQuestIDs = function()
          error("boom")
        end,
      }
      assert.is_nil(P.ReadCompletedQuestIDs())
      _G.C_QuestLog = {
        GetAllCompletedQuestIDs = function()
          return { 1 }
        end,
      }
      _G.issecretvalue = function()
        return true
      end
      assert.is_nil(P.ReadCompletedQuestIDs())
    end)
  end)

  describe("GetPlayerDisplayName", function()
    it("prefers GetUnitName without the realm", function()
      local seen
      _G.GetUnitName = function(unit, withRealm)
        seen = { unit, withRealm }
        return "Mary Ann"
      end
      _G.UnitName = function()
        return "Mary"
      end
      assert.are.equal("Mary Ann", P.GetPlayerDisplayName())
      assert.are.same({ "player", false }, seen)
    end)

    it("falls back to UnitName and then to nil", function()
      _G.UnitName = function()
        return "Mary"
      end
      assert.are.equal("Mary", P.GetPlayerDisplayName())
      _G.UnitName = nil
      assert.is_nil(P.GetPlayerDisplayName())
    end)
  end)

  describe("GetFactionByIndex", function()
    it("reads the modern API", function()
      _G.C_Reputation = {
        GetFactionDataByIndex = function(index)
          return { name = "F" .. index, factionID = 72, reaction = 8, currentStanding = 42500 }
        end,
      }
      local data = P.GetFactionByIndex(2)
      assert.are.equal("F2", data.name)
      assert.are.equal(72, data.factionID)
      assert.are.equal(8, data.standingID)
      assert.are.equal(42500, data.barValue)
      assert.are.equal("C_Reputation.GetFactionDataByIndex", data.source)
    end)

    it("falls back to GetFactionInfo", function()
      _G.GetFactionInfo = function()
        return "Legacy", "", 7, 21000, 42000, 30000, false, false, false, false, true, false, false, 69
      end
      local data = P.GetFactionByIndex(1)
      assert.are.equal("Legacy", data.name)
      assert.are.equal(69, data.factionID)
      assert.are.equal(7, data.standingID)
      assert.are.equal(30000, data.barValue)
      assert.are.equal("GetFactionInfo", data.source)
    end)

    it("gives nil when nothing answers", function()
      assert.is_nil(P.GetFactionByIndex(1))
    end)
  end)

  describe("GetCollectedMountCount", function()
    local function journal(ids, collected)
      _G.C_MountJournal = {
        GetMountIDs = function()
          return ids
        end,
        GetMountInfoByID = function(id)
          return "m", 1, 1, false, true, 0, false, false, nil, false, collected[id], id
        end,
      }
    end

    it("counts the collected mounts", function()
      journal({ 1, 2, 3 }, { [1] = true, [2] = false, [3] = true })
      assert.are.equal(2, P.GetCollectedMountCount())
    end)

    it("is 0 for an empty journal and nil without one", function()
      journal({}, {})
      assert.are.equal(0, P.GetCollectedMountCount())
      _G.C_MountJournal = nil
      assert.is_nil(P.GetCollectedMountCount())
    end)

    it("is nil when no mount can be read", function()
      _G.C_MountJournal = {
        GetMountIDs = function()
          return { 1, 2 }
        end,
        GetMountInfoByID = function()
          error("boom")
        end,
      }
      assert.is_nil(P.GetCollectedMountCount())
    end)
  end)

  describe("NewFrame", function()
    it("creates a frame", function()
      _G.CreateFrame = function()
        return { marker = true }
      end
      assert.is_true(P.NewFrame().marker)
    end)

    it("gives nil when the client cannot create frames", function()
      _G.CreateFrame = nil
      assert.is_nil(P.NewFrame())
      _G.CreateFrame = function()
        error("no frames")
      end
      assert.is_nil(P.NewFrame())
      _G.CreateFrame = function()
        return 5
      end
      assert.is_nil(P.NewFrame())
    end)
  end)

  describe("After", function()
    it("schedules through C_Timer.After", function()
      local seconds, fn
      _G.C_Timer = {
        After = function(delay, callback)
          seconds, fn = delay, callback
        end,
      }
      local callback = function() end
      assert.is_true(P.After(0.5, callback))
      assert.are.equal(0.5, seconds)
      assert.are.equal(callback, fn)
    end)

    it("is false without a timer or when it raises", function()
      assert.is_false(P.After(1, function() end))
      _G.C_Timer = {
        After = function()
          error("boom")
        end,
      }
      assert.is_false(P.After(1, function() end))
    end)
  end)
end)

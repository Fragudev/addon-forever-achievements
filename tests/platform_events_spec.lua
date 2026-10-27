local ADDON = "ForeverAchievements"

local CLIENT = {
  "UnitGUID",
  "GetInstanceInfo",
  "IsEncounterInProgress",
  "GetTime",
  "GetInventoryItemLink",
  "GetInventoryItemQuality",
  "C_Item",
  "C_ChatInfo",
  "DoEmote",
  "GOLD_AMOUNT",
  "issecretvalue",
}

describe("Platform wrappers used by the event detectors", function()
  local P

  before_each(function()
    for _, name in ipairs(CLIENT) do
      _G[name] = nil
    end
    local ns = {}
    assert(loadfile("ForeverAchievements/Core/Platform.lua"))(ADDON, ns)
    P = ns.Platform
  end)

  after_each(function()
    for _, name in ipairs(CLIENT) do
      _G[name] = nil
    end
  end)

  describe("GetUnitGUID", function()
    it("gives the GUID of the unit", function()
      local asked
      _G.UnitGUID = function(unit)
        asked = unit
        return "Creature-0-1-2-3-2442-0000ABCD"
      end
      assert.are.equal("Creature-0-1-2-3-2442-0000ABCD", P.GetUnitGUID("target"))
      assert.are.equal("target", asked)
    end)

    it("gives nil without a unit, without the API or for a secret", function()
      assert.is_nil(P.GetUnitGUID("target"))
      _G.UnitGUID = function() end
      assert.is_nil(P.GetUnitGUID("target"))
      _G.UnitGUID = function()
        return "x"
      end
      _G.issecretvalue = function()
        return true
      end
      assert.is_nil(P.GetUnitGUID("target"))
    end)
  end)

  describe("GetInstanceInfo", function()
    it("gives the type, difficulty and the instance id (8th result)", function()
      _G.GetInstanceInfo = function()
        return "Warsong Gulch", "pvp", 0, "", 0, 0, false, 489, 10
      end
      assert.are.same(
        { name = "Warsong Gulch", instanceType = "pvp", difficultyID = 0, instanceID = 489 },
        P.GetInstanceInfo()
      )
    end)

    it("gives nil when missing, raising or unreadable", function()
      assert.is_nil(P.GetInstanceInfo())
      _G.GetInstanceInfo = function()
        error("boom")
      end
      assert.is_nil(P.GetInstanceInfo())
      _G.GetInstanceInfo = function()
        return nil
      end
      assert.is_nil(P.GetInstanceInfo())
    end)

    it("keeps the readable parts when the instance id is missing", function()
      _G.GetInstanceInfo = function()
        return "World", "none", 0
      end
      local info = P.GetInstanceInfo()
      assert.are.equal("none", info.instanceType)
      assert.is_nil(info.instanceID)
    end)
  end)

  describe("IsEncounterInProgress and GetTime", function()
    it("read the client", function()
      _G.IsEncounterInProgress = function()
        return true
      end
      _G.GetTime = function()
        return 12.5
      end
      assert.is_true(P.IsEncounterInProgress())
      assert.are.equal(12.5, P.GetTime())
    end)

    it("give nil when the client cannot say", function()
      assert.is_nil(P.IsEncounterInProgress())
      assert.is_nil(P.GetTime())
      _G.IsEncounterInProgress = function()
        error("boom")
      end
      assert.is_nil(P.IsEncounterInProgress())
    end)
  end)

  describe("GetEquippedItemQuality", function()
    it("reads the quality of the equipped link", function()
      _G.GetInventoryItemLink = function(unit, slot)
        assert.are.equal("player", unit)
        return slot == 1 and "|Hitem:5|h[Helm]|h" or nil
      end
      _G.C_Item = {
        GetItemQualityByID = function(link)
          assert.is_truthy(link:find("item:5", 1, true))
          return 4
        end,
      }
      assert.are.equal(4, P.GetEquippedItemQuality(1))
      assert.is_nil(P.GetEquippedItemQuality(2))
    end)

    it("falls back to GetInventoryItemQuality", function()
      _G.GetInventoryItemLink = function()
        return "|Hitem:5|h[Helm]|h"
      end
      _G.GetInventoryItemQuality = function(unit, slot)
        assert.are.same({ "player", 3 }, { unit, slot })
        return 3
      end
      assert.are.equal(3, P.GetEquippedItemQuality(3))
    end)

    it("gives nil when nothing answers", function()
      _G.GetInventoryItemLink = function()
        return "|Hitem:5|h[Helm]|h"
      end
      assert.is_nil(P.GetEquippedItemQuality(1))
    end)
  end)

  describe("GetGlobalString", function()
    it("gives a string global", function()
      _G.GOLD_AMOUNT = "%d Gold"
      assert.are.equal("%d Gold", P.GetGlobalString("GOLD_AMOUNT"))
    end)

    it("gives nil for a missing, non-string or secret global", function()
      assert.is_nil(P.GetGlobalString("GOLD_AMOUNT"))
      _G.GOLD_AMOUNT = 5
      assert.is_nil(P.GetGlobalString("GOLD_AMOUNT"))
      _G.GOLD_AMOUNT = "%d Gold"
      _G.issecretvalue = function()
        return true
      end
      assert.is_nil(P.GetGlobalString("GOLD_AMOUNT"))
    end)
  end)

  describe("HookSecureMethod", function()
    it("hooks a function inside a table", function()
      _G.C_ChatInfo = { PerformEmote = function() end }
      local handler = function() end
      assert.is_true(P.HookSecureMethod("C_ChatInfo", "PerformEmote", handler))
      assert.are.equal(handler, _G.__hooks.PerformEmote)
    end)

    it("does not hook what is missing or without hooksecurefunc", function()
      assert.is_false(P.HookSecureMethod("C_ChatInfo", "PerformEmote", function() end))
      _G.C_ChatInfo = { PerformEmote = function() end }
      local real = _G.hooksecurefunc
      _G.hooksecurefunc = nil
      assert.is_false(P.HookSecureMethod("C_ChatInfo", "PerformEmote", function() end))
      _G.hooksecurefunc = real
    end)
  end)

  it("lists the event APIs, with the emote hooks as alternatives", function()
    local found = {}
    for _, group in ipairs(P.REQUIRED_APIS) do
      found[table.concat(group, "|")] = true
    end
    assert.is_true(found["GetInstanceInfo"])
    assert.is_true(found["IsEncounterInProgress"])
    assert.is_true(found["DoEmote|C_ChatInfo.PerformEmote"])
  end)
end)

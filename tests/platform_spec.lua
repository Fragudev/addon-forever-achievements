local ADDON = "ForeverAchievements"

-- Every client global these specs define, so each spec starts from a client with none of them.
local FAKE_GLOBALS = {
  "UnitLevel",
  "UnitGUID",
  "UnitName",
  "GetUnitName",
  "UnitClass",
  "UnitRace",
  "UnitFactionGroup",
  "GetNormalizedRealmName",
  "GetMoney",
  "RequestTimePlayed",
  "C_QuestLog",
  "C_Map",
  "C_MapExplorationInfo",
  "C_Reputation",
  "GetFactionInfoByID",
  "GetNumFactions",
  "GetProfessions",
  "GetProfessionInfo",
  "C_MountJournal",
  "C_PetJournal",
  "C_ToyBox",
  "GetPVPLifetimeStats",
  "GetBattlefieldWinner",
  "GetItemCount",
  "GetInventoryItemLink",
  "C_Item",
  "GetServerTime",
  "GetLocale",
  "IsInInstance",
  "C_ChatInfo",
  "GetCategoryList",
  "GetTotalAchievementPoints",
  "GetNumCompletedAchievements",
  "issecretvalue",
  "DoEmote",
}

describe("Platform", function()
  local ns, P

  before_each(function()
    for _, name in ipairs(FAKE_GLOBALS) do
      _G[name] = nil
    end
    _G.__hooks = nil
    ns = {}
    assert(loadfile("ForeverAchievements/Core/Constants.lua"))(ADDON, ns)
    assert(loadfile("ForeverAchievements/Core/Platform.lua"))(ADDON, ns)
    P = ns.Platform
  end)

  after_each(function()
    for _, name in ipairs(FAKE_GLOBALS) do
      _G[name] = nil
    end
  end)

  describe("generic guards", function()
    it("gives nil for every wrapper when the client has no API", function()
      assert.is_nil(P.GetPlayerLevel())
      assert.is_nil(P.GetPlayerGUID())
      assert.is_nil(P.GetPlayerName())
      assert.is_nil(P.GetPlayerFullName())
      assert.is_nil(P.GetPlayerClass())
      assert.is_nil(P.GetPlayerRace())
      assert.is_nil(P.GetPlayerFaction())
      assert.is_nil(P.GetRealmName())
      assert.is_nil(P.GetMoney())
      assert.is_false(P.RequestTimePlayed())
      assert.are.same({}, P.GetCompletedQuestIDs())
      assert.is_nil(P.IsQuestCompleted(1))
      assert.is_nil(P.GetBestMapForPlayer())
      assert.is_nil(P.GetMapInfo(1))
      assert.is_nil(P.GetPlayerMapPosition(1))
      assert.is_nil(P.GetExploredAreaIDsAtPosition(1, 0.5, 0.5))
      assert.is_nil(P.GetExploredMapTextures(1))
      assert.is_nil(P.GetFactionData(72))
      assert.is_nil(P.GetNumFactions())
      assert.are.same({}, P.GetProfessions())
      assert.is_nil(P.GetProfessionInfo(1))
      assert.is_nil(P.GetNumMounts())
      assert.is_nil(P.GetMountIDs())
      assert.is_nil(P.GetNumPets())
      assert.is_nil(P.GetNumLearnedToys())
      assert.is_nil(P.GetPVPLifetimeStats())
      assert.is_nil(P.GetBattlefieldWinner())
      assert.is_nil(P.GetItemCount(1))
      assert.is_nil(P.GetInventoryItemLink(16))
      assert.is_nil(P.GetItemQuality(1))
      assert.is_nil(P.GetServerTime())
      assert.is_nil(P.GetLocale())
      assert.is_nil(P.IsInInstance())
      assert.is_nil(P.IsChatMessagingLockedDown())
      assert.are.same({}, P.GetAchievementCategories())
      assert.is_nil(P.GetTotalAchievementPoints())
      assert.is_nil(P.GetNumCompletedAchievements())
    end)

    it("gives nil when the API raises", function()
      _G.UnitLevel = function()
        error("boom")
      end
      assert.is_nil(P.GetPlayerLevel())
      local status, message = P.Invoke("UnitLevel")
      assert.are.equal("error", status)
      assert.is_truthy(message:find("boom", 1, true))
    end)

    it("gives nil when the value has the wrong type", function()
      _G.UnitLevel = function()
        return "sixty"
      end
      assert.is_nil(P.GetPlayerLevel())
    end)

    it("resolves dotted paths and reports presence", function()
      _G.C_QuestLog = { IsQuestFlaggedCompleted = function() end, notAFunction = 3 }
      assert.is_true(P.Has("C_QuestLog.IsQuestFlaggedCompleted"))
      assert.is_false(P.Has("C_QuestLog.notAFunction"))
      assert.is_false(P.Has("C_QuestLog.Missing.Deeper"))
      assert.is_false(P.Has("Nothing.At.All"))
    end)

    it("turns secret values into nil", function()
      _G.issecretvalue = function(value)
        return value == 42
      end
      _G.UnitLevel = function()
        return 42
      end
      _G.GetNormalizedRealmName = function()
        return "Realm"
      end
      assert.is_nil(P.GetPlayerLevel())
      assert.are.equal("Realm", P.GetRealmName())
      local status, packed = P.Invoke("UnitLevel")
      assert.are.equal("ok", status)
      assert.are.equal(P.SECRET, packed[1])
      assert.are.equal("<secret>", tostring(P.SECRET))
    end)

    it("survives an issecretvalue that raises", function()
      _G.issecretvalue = function()
        error("nope")
      end
      assert.is_false(P.IsSecret(5))
      assert.is_false(P.IsSecret("text"))
      assert.is_false(P.IsSecret({}))
    end)

    it("detects a secret by the comparison probe when issecretvalue is absent", function()
      assert.is_false(P.IsSecret(5))
      assert.is_false(P.IsSecret("text"))
      assert.is_false(P.IsSecret(nil))
    end)
  end)

  describe("unit and character", function()
    it("reads the character", function()
      _G.UnitLevel = function(unit)
        assert.are.equal("player", unit)
        return 60
      end
      _G.UnitGUID = function()
        return "Player-1-ABC"
      end
      _G.UnitName = function()
        return "Yonemon"
      end
      _G.GetUnitName = function(_, withRealm)
        assert.is_true(withRealm)
        return "Yonemon Gg-Realm"
      end
      _G.UnitClass = function()
        return "Warrior", "WARRIOR", 1
      end
      _G.UnitRace = function()
        return "Human", "Human", 1
      end
      _G.UnitFactionGroup = function()
        return "Alliance", "Alliance"
      end
      _G.GetNormalizedRealmName = function()
        return "ClassicBetaPvP"
      end
      assert.are.equal(60, P.GetPlayerLevel())
      assert.are.equal("Player-1-ABC", P.GetPlayerGUID())
      assert.are.equal("Yonemon", P.GetPlayerName())
      assert.are.equal("Yonemon Gg-Realm", P.GetPlayerFullName())
      assert.are.same({ "Warrior", "WARRIOR", 1 }, { P.GetPlayerClass() })
      assert.are.same({ "Human", "Human", 1 }, { P.GetPlayerRace() })
      assert.are.equal("Alliance", (P.GetPlayerFaction()))
      assert.are.equal("ClassicBetaPvP", P.GetRealmName())
    end)

    it("reads money and requests the time played", function()
      local requested = false
      _G.GetMoney = function()
        return 12345
      end
      _G.RequestTimePlayed = function()
        requested = true
      end
      assert.are.equal(12345, P.GetMoney())
      assert.is_true(P.RequestTimePlayed())
      assert.is_true(requested)
    end)
  end)

  describe("quests, maps and exploration", function()
    it("reads quests, keeping false distinct from unknown", function()
      _G.C_QuestLog = {
        GetAllCompletedQuestIDs = function()
          return { 1, 2, 3 }
        end,
        IsQuestFlaggedCompleted = function(id)
          return id == 2
        end,
      }
      assert.are.same({ 1, 2, 3 }, P.GetCompletedQuestIDs())
      assert.is_true(P.IsQuestCompleted(2))
      assert.is_false(P.IsQuestCompleted(9))
    end)

    it("reads maps and the player position", function()
      _G.C_Map = {
        GetBestMapForUnit = function()
          return 1453
        end,
        GetMapInfo = function(id)
          return { name = "Stormwind City", mapType = 3, parentMapID = id + 1 }
        end,
        GetPlayerMapPosition = function()
          return CreateVector2D(0.25, 0.75)
        end,
      }
      assert.are.equal(1453, P.GetBestMapForPlayer())
      assert.are.same({ name = "Stormwind City", mapType = 3, parentMapID = 1454 }, P.GetMapInfo(1453))
      local x, y = P.GetPlayerMapPosition(1453)
      assert.are.equal(0.25, x)
      assert.are.equal(0.75, y)
    end)

    it("rejects a map record without a name and an unreadable position", function()
      _G.C_Map = {
        GetMapInfo = function()
          return { mapType = 3 }
        end,
        GetPlayerMapPosition = function()
          return {}
        end,
      }
      assert.is_nil(P.GetMapInfo(1))
      assert.is_nil(P.GetPlayerMapPosition(1))
      _G.C_Map.GetPlayerMapPosition = function()
        return {
          GetXY = function()
            error("secret")
          end,
        }
      end
      assert.is_nil(P.GetPlayerMapPosition(1))
    end)

    it("reads exploration", function()
      _G.C_MapExplorationInfo = {
        GetExploredAreaIDsAtPosition = function(mapId, vector)
          assert.are.equal(1, mapId)
          assert.are.equal(0.5, vector.x)
          return { 87 }
        end,
        GetExploredMapTextures = function()
          return { { fileDataID = 1 } }
        end,
      }
      assert.are.same({ 87 }, P.GetExploredAreaIDsAtPosition(1, 0.5, 0.5))
      assert.are.same({ { fileDataID = 1 } }, P.GetExploredMapTextures(1))
    end)

    it("gives nil when the vector cannot be built", function()
      _G.C_MapExplorationInfo = {
        GetExploredAreaIDsAtPosition = function()
          return { 87 }
        end,
      }
      local real = _G.CreateVector2D
      _G.CreateVector2D = function()
        error("no vector")
      end
      assert.is_nil(P.GetExploredAreaIDsAtPosition(1, 0.5, 0.5))
      _G.CreateVector2D = nil
      assert.is_nil(P.GetExploredAreaIDsAtPosition(1, 0.5, 0.5))
      _G.CreateVector2D = real
    end)
  end)

  describe("reputation and professions", function()
    it("prefers the modern reputation API", function()
      _G.C_Reputation = {
        GetFactionDataByID = function(id)
          return {
            name = "Stormwind",
            factionID = id,
            reaction = 5,
            currentReactionThreshold = 3000,
            nextReactionThreshold = 9000,
            currentStanding = 4000,
          }
        end,
        GetNumFactions = function()
          return 12
        end,
      }
      local data = P.GetFactionData(72)
      assert.are.equal("Stormwind", data.name)
      assert.are.equal(5, data.standingID)
      assert.are.equal(4000, data.barValue)
      assert.are.equal("C_Reputation.GetFactionDataByID", data.source)
      assert.are.equal(12, P.GetNumFactions())
    end)

    it("falls back to the old reputation API", function()
      _G.GetFactionInfoByID = function()
        return "Stormwind", "text", 5, 3000, 9000, 4000
      end
      _G.GetNumFactions = function()
        return 7
      end
      local data = P.GetFactionData(72)
      assert.are.equal("GetFactionInfoByID", data.source)
      assert.are.equal(72, data.factionID)
      assert.are.equal(3000, data.barMin)
      assert.are.equal(7, P.GetNumFactions())
    end)

    it("lists professions without the empty slots", function()
      _G.GetProfessions = function()
        return 1, nil, 3, nil, 5
      end
      _G.GetProfessionInfo = function()
        return "Mining", 1, 150, 300, 1, 0, 186
      end
      assert.are.same({ 1, 3, 5 }, P.GetProfessions())
      assert.are.same({ name = "Mining", rank = 150, maxRank = 300, skillLine = 186 }, P.GetProfessionInfo(1))
    end)

    it("gives nil for a profession without a name", function()
      _G.GetProfessionInfo = function()
        return nil
      end
      assert.is_nil(P.GetProfessionInfo(1))
    end)
  end)

  describe("collections, pvp, items and client state", function()
    it("reads collections", function()
      _G.C_MountJournal = {
        GetNumMounts = function()
          return 3
        end,
        GetMountIDs = function()
          return { 6, 7 }
        end,
      }
      _G.C_PetJournal = {
        GetNumPets = function()
          return 10, 4
        end,
      }
      _G.C_ToyBox = {
        GetNumLearnedDisplayedToys = function()
          return 2
        end,
      }
      assert.are.equal(3, P.GetNumMounts())
      assert.are.same({ 6, 7 }, P.GetMountIDs())
      assert.are.same({ 10, 4 }, { P.GetNumPets() })
      assert.are.equal(2, P.GetNumLearnedToys())
    end)

    it("reads pvp, items and client state", function()
      _G.GetPVPLifetimeStats = function()
        return 100, 0, 0
      end
      _G.GetBattlefieldWinner = function()
        return 1
      end
      _G.GetItemCount = function()
        return 1
      end
      _G.GetInventoryItemLink = function()
        return "|Hitem:1|h[Sword]|h"
      end
      _G.C_Item = {
        GetItemQualityByID = function()
          return 4
        end,
      }
      _G.GetServerTime = function()
        return 1700000000
      end
      _G.GetLocale = function()
        return "esMX"
      end
      _G.IsInInstance = function()
        return true, "raid"
      end
      _G.C_ChatInfo = {
        InChatMessagingLockdown = function()
          return false
        end,
      }
      assert.are.equal(100, (P.GetPVPLifetimeStats()))
      assert.are.equal(1, P.GetBattlefieldWinner())
      assert.are.equal(1, P.GetItemCount(6948, true))
      assert.is_truthy(P.GetInventoryItemLink(16))
      assert.are.equal(4, P.GetItemQuality(1))
      assert.are.equal(1700000000, P.GetServerTime())
      assert.are.equal("esMX", P.GetLocale())
      assert.are.same({ true, "raid" }, { P.IsInInstance() })
      assert.is_false(P.IsChatMessagingLockedDown())
    end)

    it("reads the native achievement system", function()
      _G.GetCategoryList = function()
        return { 92, 96 }
      end
      _G.GetTotalAchievementPoints = function()
        return 0
      end
      _G.GetNumCompletedAchievements = function()
        return 0, 900
      end
      assert.are.same({ 92, 96 }, P.GetAchievementCategories())
      assert.are.equal(0, P.GetTotalAchievementPoints())
      assert.are.same({ 0, 900 }, { P.GetNumCompletedAchievements() })
    end)
  end)

  describe("hooks and events", function()
    it("hooks a global function", function()
      _G.DoEmote = function() end
      local handler = function() end
      assert.is_true(P.HookSecure("DoEmote", handler))
      assert.are.equal(handler, _G.__hooks.DoEmote)
    end)

    it("does not hook a missing function or without hooksecurefunc", function()
      assert.is_false(P.HookSecure("DoEmote", function() end))
      _G.DoEmote = function() end
      local real = _G.hooksecurefunc
      _G.hooksecurefunc = nil
      assert.is_false(P.HookSecure("DoEmote", function() end))
      _G.hooksecurefunc = real
    end)

    it("registers events and reports the refused ones", function()
      local frame = CreateFrame("Frame")
      local original = frame.RegisterEvent
      frame.RegisterEvent = function(self, event)
        if event == "BROKEN_EVENT" then
          error("unknown event")
        end
        return original(self, event)
      end
      local outcome = P.RegisterEvents(frame, { "PLAYER_LEVEL_UP", "BROKEN_EVENT" })
      assert.are.same({ "PLAYER_LEVEL_UP" }, outcome.registered)
      assert.are.same({ "BROKEN_EVENT" }, outcome.refused)
      assert.is_true(frame.events.PLAYER_LEVEL_UP)
    end)

    it("never registers the combat log", function()
      local frame = CreateFrame("Frame")
      assert.is_false(P.TryRegisterEvent(frame, "COMBAT_LOG_EVENT_UNFILTERED"))
      assert.is_nil(frame.events.COMBAT_LOG_EVENT_UNFILTERED)
    end)
  end)

  it("lists the required APIs as groups of alternatives", function()
    assert.is_true(#P.REQUIRED_APIS > 20)
    for _, group in ipairs(P.REQUIRED_APIS) do
      assert.is_true(#group >= 1)
    end
  end)
end)

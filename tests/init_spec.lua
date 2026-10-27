local Env = dofile("tests/support/detector_env.lua")

local ADDON = "ForeverAchievements"

describe("Init", function()
  local env, ns, frame, printed, realPrint

  before_each(function()
    env = Env.Build()
    ns = env.ns
    printed = {}
    realPrint = _G.print
    _G.print = function(...)
      printed[#printed + 1] = table.concat({ ... }, " ")
    end
    -- Capture the Init frame; the client globals the app reads are left undefined (no character data).
    local realCreateFrame = env.realCreateFrame
    _G.CreateFrame = function(...)
      frame = realCreateFrame(...)
      return frame
    end
    _G.ForeverAchievementsDB = nil
    assert(loadfile("ForeverAchievements/Core/Init.lua"))(ADDON, ns)
  end)

  after_each(function()
    _G.print = realPrint
    env.close()
    _G.ForeverAchievementsDB = nil
  end)

  local function event(name, ...)
    frame.scripts.OnEvent(frame, name, ...)
  end

  local function output()
    return table.concat(printed, "\n")
  end

  describe("ADDON_LOADED", function()
    it("creates the saved variables", function()
      event("ADDON_LOADED", ADDON)
      assert.are.equal(1, ForeverAchievementsDB.schema)
      assert.are.equal(ForeverAchievementsDB, ns.db)
      assert.are.equal(ForeverAchievementsDB, ns.store:Db())
    end)

    it("keeps existing saved variables and migrates them in place", function()
      local saved = { schema = 1, marker = true, characters = { ["Player-9"] = { name = "Old" } } }
      _G.ForeverAchievementsDB = saved
      event("ADDON_LOADED", ADDON)
      assert.are.equal(saved, ForeverAchievementsDB)
      assert.is_true(ForeverAchievementsDB.marker)
      assert.are.equal("Old", ForeverAchievementsDB.characters["Player-9"].name)
    end)

    it("stamps new characters with the server time when there is one", function()
      _G.GetServerTime = function()
        return 555
      end
      event("ADDON_LOADED", ADDON)
      assert.are.equal(555, ns.store:GetCharacter("Player-1").lastSeen)
    end)

    it("falls back to os.time", function()
      event("ADDON_LOADED", ADDON)
      assert.is_true(ns.store:GetCharacter("Player-1").lastSeen > 1000000)
    end)

    it("ignores other addons", function()
      event("ADDON_LOADED", "SomethingElse")
      assert.is_nil(ForeverAchievementsDB)
      assert.is_nil(ns.store)
    end)

    it("disables the addon with one warning when the data comes from a newer schema", function()
      local saved = { schema = 99, characters = {} }
      _G.ForeverAchievementsDB = saved
      event("ADDON_LOADED", ADDON)
      assert.are.equal("newer_schema", ns.disabled)
      assert.are.equal(saved, ForeverAchievementsDB)
      assert.are.equal(99, ForeverAchievementsDB.schema)
      assert.is_nil(ns.store)
      assert.are.equal(1, #printed)
      assert.is_truthy(output():find("schema 99", 1, true))

      event("PLAYER_LOGIN")
      assert.are.equal(1, #printed)
      assert.is_nil(ns.App)
    end)
  end)

  describe("PLAYER_LOGIN", function()
    it("announces itself", function()
      event("PLAYER_LOGIN")
      assert.is_truthy(printed[1]:find("dev loaded", 1, true))
      assert.is_nil(ns.App)
    end)

    it("builds and starts the app once the store is open", function()
      _G.UnitGUID = function()
        return "Player-7"
      end
      _G.UnitLevel = function()
        return 12
      end
      event("ADDON_LOADED", ADDON)
      event("PLAYER_LOGIN")
      assert.is_truthy(printed[1]:find("dev loaded", 1, true))
      assert.is_table(ns.App)
      assert.are.equal(ns.store, ns.App.store)
      assert.are.equal(12, ns.store:FindCharacter("Player-7").level)
    end)

    it("reports a failure to start instead of raising", function()
      event("ADDON_LOADED", ADDON)
      ns.AppBuilder.Build = function()
        error("boom")
      end
      assert.has_no.errors(function()
        event("PLAYER_LOGIN")
      end)
      assert.is_truthy(output():find("could not start", 1, true))
      assert.is_nil(ns.App)
    end)
  end)

  it("uses the TOC version when it is set", function()
    _G.C_AddOns.GetAddOnMetadata = function()
      return "1.2.3"
    end
    assert.are.equal("1.2.3", ns.GetVersion())
    _G.C_AddOns.GetAddOnMetadata = function()
      return "@project-version@"
    end
  end)
end)

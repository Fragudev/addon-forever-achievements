local ADDON = "ForeverAchievements"

describe("Init", function()
  local ns, frame, printed, realPrint, realCreateFrame

  before_each(function()
    printed = {}
    realPrint = _G.print
    _G.print = function(...)
      printed[#printed + 1] = table.concat({ ... }, " ")
    end
    realCreateFrame = _G.CreateFrame
    _G.CreateFrame = function(...)
      frame = realCreateFrame(...)
      return frame
    end
    _G.ForeverAchievementsDB = nil
    ns = {}
    assert(loadfile("ForeverAchievements/Core/Constants.lua"))(ADDON, ns)
    assert(loadfile("ForeverAchievements/Core/Init.lua"))(ADDON, ns)
  end)

  after_each(function()
    _G.print = realPrint
    _G.CreateFrame = realCreateFrame
  end)

  it("creates the saved variables on ADDON_LOADED", function()
    frame.scripts.OnEvent(frame, "ADDON_LOADED", ADDON)
    assert.are.equal(1, ForeverAchievementsDB.schema)
    assert.are.equal(ForeverAchievementsDB, ns.db)
  end)

  it("keeps existing saved variables", function()
    _G.ForeverAchievementsDB = { schema = 1, marker = true }
    frame.scripts.OnEvent(frame, "ADDON_LOADED", ADDON)
    assert.is_true(ForeverAchievementsDB.marker)
  end)

  it("ignores other addons", function()
    frame.scripts.OnEvent(frame, "ADDON_LOADED", "SomethingElse")
    assert.is_nil(ForeverAchievementsDB)
  end)

  it("announces itself on PLAYER_LOGIN", function()
    frame.scripts.OnEvent(frame, "PLAYER_LOGIN")
    assert.is_truthy(printed[1]:find("dev loaded", 1, true))
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

  it("answers /fach with the version", function()
    assert.are.equal("/fach", SLASH_FACH1)
    SlashCmdList["FACH"]()
    assert.is_truthy(printed[1]:find("dev", 1, true))
  end)
end)

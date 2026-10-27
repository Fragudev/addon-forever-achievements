local ADDON = "ForeverAchievements"

describe("Slash", function()
  local ns, printed, realPrint

  before_each(function()
    printed = {}
    realPrint = _G.print
    _G.print = function(...)
      printed[#printed + 1] = table.concat({ ... }, " ")
    end
    _G.SlashCmdList = {}
    _G.SLASH_FACH1 = nil
    ns = {}
    assert(loadfile("ForeverAchievements/Core/Constants.lua"))(ADDON, ns)
    assert(loadfile("ForeverAchievements/Core/Platform.lua"))(ADDON, ns)
    assert(loadfile("ForeverAchievements/Core/Probe.lua"))(ADDON, ns)
    assert(loadfile("ForeverAchievements/Commands/Slash.lua"))(ADDON, ns)
    ns.GetVersion = function()
      return "9.9.9"
    end
  end)

  after_each(function()
    _G.print = realPrint
  end)

  local function output()
    return table.concat(printed, "\n")
  end

  it("registers /fach", function()
    assert.are.equal("/fach", SLASH_FACH1)
    assert.is_function(SlashCmdList["FACH"])
  end)

  it("prints the version and the help for a bare /fach", function()
    SlashCmdList["FACH"]("")
    assert.is_truthy(output():find("9.9.9", 1, true))
    assert.is_truthy(output():find("/fach debug", 1, true))
  end)

  it("reports an unknown command and shows the help", function()
    SlashCmdList["FACH"]("nonsense")
    assert.is_truthy(output():find("unknown command 'nonsense'", 1, true))
    assert.is_truthy(output():find("commands:", 1, true))
  end)

  it("runs debug probe, its events report and selftest", function()
    SlashCmdList["FACH"]("debug probe")
    assert.is_truthy(output():find("probe version=9.9.9", 1, true))
    printed = {}
    SlashCmdList["FACH"]("debug probe events")
    assert.is_truthy(output():find("not started", 1, true))
    printed = {}
    SlashCmdList["FACH"]("DEBUG selftest")
    assert.is_truthy(output():find("selftest %d+/%d+ APIs OK"))
  end)

  it("shows the debug help for a missing or unknown debug command", function()
    SlashCmdList["FACH"]("debug")
    assert.is_truthy(output():find("debug commands:", 1, true))
    assert.is_truthy(output():find("/fach debug probe", 1, true))
    printed = {}
    SlashCmdList["FACH"]("debug nope")
    assert.is_truthy(output():find("debug commands:", 1, true))
  end)

  it("lets later phases add commands and debug commands", function()
    local received
    ns.Slash.Register("stats", function(rest)
      received = rest
    end, "stats [name]      show statistics")
    ns.Slash.RegisterDebug("dump", function(rest)
      received = "dump:" .. rest
    end, "dump             dump state")
    SlashCmdList["FACH"]("stats  all of them ")
    assert.are.equal("all of them", received)
    SlashCmdList["FACH"]("debug dump now")
    assert.are.equal("dump:now", received)
    printed = {}
    SlashCmdList["FACH"]("")
    assert.is_truthy(output():find("stats [name]", 1, true))
  end)

  it("replaces a command registered twice", function()
    local calls = {}
    ns.Slash.Register("dup", function()
      calls[#calls + 1] = "first"
    end, "dup")
    ns.Slash.Register("dup", function()
      calls[#calls + 1] = "second"
    end, "dup")
    SlashCmdList["FACH"]("dup")
    assert.are.same({ "second" }, calls)
  end)

  it("keeps a failing command from raising", function()
    ns.Slash.Register("bad", function()
      error("boom")
    end, "bad")
    assert.has_no.errors(function()
      SlashCmdList["FACH"]("bad")
    end)
    assert.is_truthy(output():find("error in /fach bad", 1, true))
  end)
end)

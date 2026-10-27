local Loader = dofile("tests/support/loader.lua")

local function load_locale()
  return Loader.Load({ "Core/Constants.lua", "Core/Locale.lua" })
end

describe("Locale", function()
  local ns

  before_each(function()
    ns = load_locale()
    ns.Locale.Register("enUS", { greeting = "Hello", only_english = "English only" })
    ns.Locale.Register("esES", { greeting = "Hola" })
  end)

  it("reads the active locale", function()
    ns.Locale.Use("esES")
    assert.are.equal("Hola", ns.L["greeting"])
  end)

  it("falls back to enUS and then to the key", function()
    ns.Locale.Use("esES")
    assert.are.equal("English only", ns.L["only_english"])
    assert.are.equal("no.such.key", ns.L["no.such.key"])
  end)

  it("maps esMX to esES", function()
    assert.are.equal("esES", ns.Locale.Use("esMX"))
    assert.are.equal("Hola", ns.L["greeting"])
  end)

  it("uses enUS for any other client locale", function()
    assert.are.equal("enUS", ns.Locale.Use("deDE"))
    assert.are.equal("enUS", ns.Locale.Use(nil))
    assert.are.equal("Hello", ns.L["greeting"])
    assert.are.equal("enUS", ns.Locale.Current())
  end)

  it("merges repeated registrations", function()
    ns.Locale.Register("enUS", { extra = "Extra" })
    assert.are.equal("Extra", ns.Locale.Get("enUS").extra)
    assert.are.equal("Hello", ns.Locale.Get("enUS").greeting)
  end)

  describe("client locale at load", function()
    local realGetLocale

    before_each(function()
      realGetLocale = _G.GetLocale
    end)

    after_each(function()
      _G.GetLocale = realGetLocale
    end)

    it("reads GetLocale", function()
      _G.GetLocale = function()
        return "esMX"
      end
      assert.are.equal("esES", load_locale().Locale.Current())
    end)

    it("survives a GetLocale that raises", function()
      _G.GetLocale = function()
        error("boom")
      end
      assert.are.equal("enUS", load_locale().Locale.Current())
    end)

    it("survives a missing GetLocale", function()
      _G.GetLocale = nil
      assert.are.equal("enUS", load_locale().Locale.Current())
    end)
  end)
end)

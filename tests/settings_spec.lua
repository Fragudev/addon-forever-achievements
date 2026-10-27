local Harness = dofile("tests/support/harness.lua")

describe("Settings", function()
  local h, settings

  before_each(function()
    h = Harness.Build()
    settings = h.ns.Settings.New(h.store)
  end)

  it("returns the defaults", function()
    assert.is_true(settings:Get("toasts"))
    assert.is_true(settings:Get("chat"))
    assert.is_true(settings:Get("sound"))
    assert.are.same({}, settings:Get("tracked"))
    assert.are.equal(200, settings:Get("minimap").angle)
    assert.is_nil(settings:Get("nope"))
  end)

  it("sets valid values", function()
    assert.is_true(settings:Set("toasts", false))
    assert.is_false(settings:Get("toasts"))
    assert.is_true(settings:Set("minimap", { angle = 90 }))
    assert.are.equal(90, settings:Get("minimap").angle)
    assert.is_true(settings:Set("tracked", { "a" }))
    assert.are.same({ "a" }, settings:Get("tracked"))
  end)

  it("rejects unknown keys and invalid values", function()
    local ok, reason = settings:Set("nope", true)
    assert.is_false(ok)
    assert.are.equal("unknown", reason)
    ok, reason = settings:Set("sound", "loud")
    assert.is_false(ok)
    assert.are.equal("invalid", reason)
    assert.is_false(settings:Set("minimap", { angle = "x" }))
    assert.is_true(settings:Get("sound"))
  end)

  it("repairs a damaged stored value instead of raising", function()
    h.store:Settings().chat = "yes"
    h.store:Settings().minimap = 5
    h.store:Settings().tracked = nil
    assert.is_true(settings:Get("chat"))
    assert.are.equal(200, settings:Get("minimap").angle)
    assert.are.same({}, settings:Get("tracked"))
  end)

  it("hands out a fresh default each time", function()
    h.store:Settings().tracked = nil
    local first = settings:Get("tracked")
    first[1] = "x"
    assert.are.equal(first, settings:Get("tracked"))
    assert.are.equal(0, #h.store.DEFAULT_SETTINGS.tracked)
  end)
end)

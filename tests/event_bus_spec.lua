local Loader = dofile("tests/support/loader.lua")

describe("EventBus", function()
  local bus

  before_each(function()
    local ns = Loader.Load({ "Core/Constants.lua", "Core/EventBus.lua" })
    bus = ns.EventBus.New()
  end)

  it("delivers the payload to every subscriber in order", function()
    local seen = {}
    bus:Subscribe("e", function(a, b)
      seen[#seen + 1] = "first:" .. a .. b
    end)
    bus:Subscribe("e", function(a)
      seen[#seen + 1] = "second:" .. a
    end)
    assert.are.equal(2, bus:Publish("e", "x", "y"))
    assert.are.same({ "first:xy", "second:x" }, seen)
  end)

  it("publishing without subscribers is harmless", function()
    assert.are.equal(0, bus:Publish("nobody"))
  end)

  it("isolates a failing handler and records its error", function()
    local ran = false
    bus:Subscribe("e", function()
      error("boom")
    end)
    bus:Subscribe("e", function()
      ran = true
    end)
    assert.are.equal(1, bus:Publish("e"))
    assert.is_true(ran)
    local errors = bus:Errors()
    assert.are.equal(1, #errors)
    assert.are.equal("e", errors[1].event)
    assert.is_truthy(errors[1].error:find("boom", 1, true))
  end)

  it("keeps only the most recent errors and can clear them", function()
    bus:Subscribe("e", function()
      error("x")
    end)
    for _ = 1, bus.MAX_ERRORS + 5 do
      bus:Publish("e")
    end
    assert.are.equal(bus.MAX_ERRORS, #bus:Errors())
    bus:ClearErrors()
    assert.are.equal(0, #bus:Errors())
  end)

  it("unsubscribes", function()
    local calls = 0
    local handler = bus:Subscribe("e", function()
      calls = calls + 1
    end)
    assert.is_true(bus:Unsubscribe("e", handler))
    assert.is_false(bus:Unsubscribe("e", handler))
    assert.is_false(bus:Unsubscribe("other", handler))
    bus:Publish("e")
    assert.are.equal(0, calls)
  end)

  it("lets a handler unsubscribe itself while publishing", function()
    local calls = 0
    local handler
    handler = bus:Subscribe("e", function()
      calls = calls + 1
      bus:Unsubscribe("e", handler)
    end)
    bus:Subscribe("e", function()
      calls = calls + 10
    end)
    bus:Publish("e")
    bus:Publish("e")
    assert.are.equal(21, calls)
  end)

  it("rejects a handler that is not a function", function()
    assert.has_error(function()
      bus:Subscribe("e", "nope")
    end)
  end)
end)

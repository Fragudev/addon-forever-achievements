local Harness = dofile("tests/support/harness.lua")

describe("StatisticsService", function()
  local h, stats

  before_each(function()
    h = Harness.Build()
    stats = h.ns.StatisticsService.New({
      store = h.store,
      guid = function()
        return h.guid
      end,
    })
  end)

  it("loads the definitions from Data/Statistics.lua", function()
    local Statistics = h.ns.StatisticsService
    assert.is_true(#Statistics.Definitions() >= 3)
    assert.are.equal("deaths", Statistics.Definitions()[1].id)
    assert.are.equal("counter", Statistics.Definition("deaths").kind)
    assert.is_nil(Statistics.Definition("nope"))
  end)

  it("does not duplicate a definition registered twice", function()
    local before = #h.ns.StatisticsService.Definitions()
    h.ns.StatisticsService.Register({ { id = "deaths", category = "c", name = "n", kind = "counter" } })
    assert.are.equal(before, #h.ns.StatisticsService.Definitions())
    h.ns.StatisticsService.Register({
      { id = "deaths", category = "stat.cat.general", name = "stat.deaths", kind = "counter" },
    })
  end)

  it("increments a counter, default 1", function()
    assert.are.equal(1, stats:Increment("deaths"))
    assert.are.equal(4, stats:Increment("deaths", 3))
    assert.are.equal(4, stats:Get("deaths"))
    assert.are.equal(4, h.store:Stats("Player-1").deaths)
  end)

  it("keeps counters per character", function()
    stats:Increment("deaths")
    h.store:GetCharacter("Player-2", {})
    h.guid = "Player-2"
    assert.are.equal(0, stats:Get("deaths"))
  end)

  it("keeps the highest value of a max statistic", function()
    assert.are.equal(30, stats:SetMax("highest_level", 30))
    assert.are.equal(30, stats:SetMax("highest_level", 12))
    assert.are.equal(30, stats:Get("highest_level"))
  end)

  it("rejects unknown ids, wrong kinds and bad values", function()
    local value, reason = stats:Increment("nope")
    assert.is_nil(value)
    assert.are.equal("unknown", reason)
    assert.are.equal("invalid", select(2, stats:Increment("highest_level")))
    assert.are.equal("invalid", select(2, stats:Increment("deaths", -1)))
    assert.are.equal("invalid", select(2, stats:Increment("deaths", "x")))
    assert.are.equal("unknown", select(2, stats:SetMax("nope", 1)))
    assert.are.equal("invalid", select(2, stats:SetMax("deaths", 1)))
    assert.are.equal("invalid", select(2, stats:SetMax("highest_level", "x")))
  end)

  it("needs a current character", function()
    h.guid = nil
    assert.are.equal("no_character", select(2, stats:Increment("deaths")))
    assert.are.equal("no_character", select(2, stats:SetMax("highest_level", 3)))
    assert.are.equal(0, stats:Get("deaths"))
  end)

  it("lists every definition with its value", function()
    stats:Increment("deaths", 2)
    local list = stats:List()
    assert.are.equal(#h.ns.StatisticsService.Definitions(), #list)
    assert.are.equal("deaths", list[1].definition.id)
    assert.are.equal(2, list[1].value)
    assert.are.equal(0, list[2].value)
  end)
end)

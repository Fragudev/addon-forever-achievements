local UiHarness = dofile("tests/support/ui_harness.lua")

describe("ViewModelStatistics", function()
  local h, Statistics

  before_each(function()
    h = UiHarness.Build()
    h.ns.Locale.Use("enUS")
    Statistics = h.ns.ViewModelStatistics
  end)

  it("groups the definitions by category with the current character's values", function()
    h.stats:Increment("deaths", 12)
    h.stats:SetMax("highest_level", 1234)
    local groups = Statistics.Build(h.app)
    assert.are.equal(1, #groups)
    assert.are.equal("General", groups[1].name)
    assert.are.equal("Total deaths", groups[1].rows[1].name)
    assert.are.equal(12, groups[1].rows[1].value)
    assert.are.equal("12", groups[1].rows[1].text)
    assert.are.equal("1,234", groups[1].rows[3].text)
    assert.are.equal("0", groups[1].rows[2].text)
  end)

  it("reads zero without a character and follows the active locale", function()
    h.guid = nil
    h.ns.Locale.Use("esES")
    local groups = Statistics.Build(h.app)
    assert.are.equal("Muertes totales", groups[1].rows[1].name)
    assert.are.equal(0, groups[1].rows[1].value)
  end)

  it("keeps several categories in registration order", function()
    h.ns.StatisticsService.Register({
      { id = "gold_looted", category = "stat.cat.general", name = "stat.deaths", kind = "counter" },
      { id = "zz", category = "stat.cat.other", name = "stat.deaths", kind = "counter" },
    })
    local groups = Statistics.Build(h.app)
    assert.are.equal(2, #groups)
    assert.are.equal("stat.cat.other", groups[2].id)
    assert.are.equal(4, #groups[1].rows)
  end)
end)

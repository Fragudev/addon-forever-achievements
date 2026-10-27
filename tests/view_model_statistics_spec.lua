local UiHarness = dofile("tests/support/ui_harness.lua")

describe("ViewModelStatistics", function()
  local h, Statistics

  before_each(function()
    h = UiHarness.Build()
    h.ns.Locale.Use("enUS")
    Statistics = h.ns.ViewModelStatistics
  end)

  local function group(groups, id)
    for _, candidate in ipairs(groups) do
      if candidate.id == id then
        return candidate
      end
    end
  end

  local function row(g, id)
    for _, candidate in ipairs(g.rows) do
      if candidate.id == id then
        return candidate
      end
    end
  end

  it("groups the definitions by category with the current character's values", function()
    h.stats:Increment("deaths", 12)
    h.stats:SetMax("highest_level", 1234)
    local groups = Statistics.Build(h.app)
    local ids = {}
    for index, g in ipairs(groups) do
      ids[index] = g.id
    end
    assert.are.same(
      { "stat.cat.general", "stat.cat.combat", "stat.cat.pvp", "stat.cat.wealth", "stat.cat.collections" },
      ids
    )
    local general = groups[1]
    assert.are.equal("General", general.name)
    assert.are.equal("Total deaths", general.rows[1].name)
    assert.are.equal(12, general.rows[1].value)
    assert.are.equal("12", general.rows[1].text)
    assert.are.equal("1,234", row(general, "highest_level").text)
    assert.are.equal("0", row(general, "quests_completed").text)
  end)

  it("shows a money statistic as gold, silver and copper", function()
    h.stats:Increment("gold_looted", 123456)
    local wealth = group(Statistics.Build(h.app), "stat.cat.wealth")
    assert.are.equal("Wealth", wealth.name)
    assert.are.equal("12g 34s 56c", row(wealth, "gold_looted").text)
  end)

  it("reads zero without a character and follows the active locale", function()
    h.guid = nil
    h.ns.Locale.Use("esES")
    local groups = Statistics.Build(h.app)
    assert.are.equal("Muertes totales", groups[1].rows[1].name)
    assert.are.equal("Combate", groups[2].name)
    assert.are.equal(0, groups[1].rows[1].value)
  end)

  it("keeps several categories in registration order", function()
    h.ns.StatisticsService.Register({
      { id = "extra", category = "stat.cat.general", name = "stat.deaths", kind = "counter" },
      { id = "zz", category = "stat.cat.other", name = "stat.deaths", kind = "counter" },
    })
    local groups = Statistics.Build(h.app)
    assert.are.equal(6, #groups)
    assert.are.equal("stat.cat.other", groups[6].id)
    assert.are.equal("extra", groups[1].rows[5].id)
  end)
end)

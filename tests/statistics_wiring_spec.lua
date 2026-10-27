local Harness = dofile("tests/support/harness.lua")
local Loader = dofile("tests/support/loader.lua")

describe("StatisticsWiring", function()
  local h, ns, stats

  before_each(function()
    h = Harness.Build()
    ns = h.ns
    stats = ns.StatisticsService.New({
      store = h.store,
      guid = function()
        return h.guid
      end,
    })
    ns.StatisticsWiring.Attach(h.bus, stats)
  end)

  local function feed(factType, value, key, extra)
    local fact = { type = factType, key = key, value = value }
    for field, v in pairs(extra or {}) do
      fact[field] = v
    end
    return h.engine:Feed(fact)
  end

  it("counts deaths", function()
    feed("death", 1)
    feed("death", 1)
    assert.are.equal(2, stats:Get("deaths"))
  end)

  it("keeps the highest level, retro facts included", function()
    h.award:Silent(function()
      feed("level", 60)
    end)
    feed("level", 12)
    assert.are.equal(60, stats:Get("highest_level"))
  end)

  it("counts bosses and splits dungeons from raids", function()
    feed("encounter", 1, 1084, { instanceType = "raid" })
    feed("encounter", 1, 1085, { instanceType = "party" })
    feed("encounter", 1, 1086, { instanceType = "party" })
    feed("encounter", 1, 1087)
    assert.are.equal(4, stats:Get("bosses_killed"))
    assert.are.equal(1, stats:Get("raid_bosses"))
    assert.are.equal(2, stats:Get("dungeon_bosses"))
  end)

  it("counts battlegrounds in total and per map", function()
    feed("bg_played", 1, 489)
    feed("bg_played", 1, 489)
    feed("bg_played", 1, 529)
    feed("bg_win", 1, 489)
    assert.are.equal(3, stats:Get("bg_played"))
    assert.are.equal(2, stats:Get("bg_played_489"))
    assert.are.equal(1, stats:Get("bg_played_529"))
    assert.are.equal(1, stats:Get("bg_won"))
    assert.are.equal(1, stats:Get("bg_won_489"))
    assert.are.equal(0, stats:Get("bg_won_529"))
  end)

  it("counts a battleground without a per-map statistic only in total", function()
    feed("bg_played", 1, 9999)
    feed("bg_played", 1)
    assert.are.equal(2, stats:Get("bg_played"))
    assert.are.equal(0, stats:Get("bg_played_9999"))
  end)

  it("keeps the maxima: honorable kills, epic items and mounts", function()
    feed("honor_kills", 150)
    feed("honor_kills", 90)
    feed("equip_quality", 5, 4)
    feed("equip_quality", 12, 3)
    feed("equip_quality", 3, 4)
    feed("mount_count", 7)
    assert.are.equal(150, stats:Get("honorable_kills"))
    assert.are.equal(5, stats:Get("epic_equipped"))
    assert.are.equal(7, stats:Get("mounts"))
  end)

  it("adds the money looted", function()
    feed("money_looted", 1234)
    feed("money_looted", 66)
    assert.are.equal(1300, stats:Get("gold_looted"))
  end)

  it("ignores types without a rule and facts the engine rejects", function()
    feed("played", 3600)
    feed("death", "x")
    assert.are.equal(0, stats:Get("deaths"))
    assert.has_no.errors(function()
      ns.StatisticsWiring.Apply(stats, nil)
      ns.StatisticsWiring.Apply(stats, { type = "death", value = "x" })
      ns.StatisticsWiring.Apply(stats, { type = "unknown", value = 1 })
    end)
  end)

  it("never raises when the statistics fail", function()
    stats.Increment = function()
      error("boom")
    end
    assert.has_no.errors(function()
      feed("death", 1)
    end)
  end)

  it("can be detached", function()
    local handler = ns.StatisticsWiring.Attach(h.bus, stats)
    assert.is_true(h.bus:Unsubscribe("fact.fed", handler))
  end)

  describe("definitions", function()
    local full = Loader.Full()

    it("have a name and a category in both locales", function()
      local en, es = full.Locale.Get("enUS"), full.Locale.Get("esES")
      for _, definition in ipairs(full.StatisticsService.Definitions()) do
        for _, key in ipairs({ definition.name, definition.category }) do
          assert.is_string(en[key], "enUS " .. key)
          assert.is_string(es[key], "esES " .. key)
        end
      end
    end)

    it("cover every id the rules write to", function()
      for _, id in ipairs({
        "deaths",
        "highest_level",
        "bosses_killed",
        "dungeon_bosses",
        "raid_bosses",
        "bg_played",
        "bg_won",
        "bg_played_489",
        "bg_played_529",
        "bg_played_30",
        "bg_won_489",
        "bg_won_529",
        "bg_won_30",
        "honorable_kills",
        "gold_looted",
        "emotes_used",
        "epic_equipped",
        "mounts",
        "quests_completed",
      }) do
        assert.is_not_nil(full.StatisticsService.Definition(id), id)
      end
    end)
  end)
end)

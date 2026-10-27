local Loader = dofile("tests/support/loader.lua")
local fixture = dofile("tests/fixtures/catalog.lua")

local function rules(errors)
  local found = {}
  for _, err in ipairs(errors) do
    found[err.rule] = (found[err.rule] or 0) + 1
  end
  return found
end

describe("Catalog", function()
  describe("indexes", function()
    local ns, Catalog

    before_each(function()
      ns = Loader.Full()
      Catalog = ns.Catalog
    end)

    it("registers the real data", function()
      assert.is_true(Catalog.Count() >= 50)
      assert.are.equal(Catalog.Count(), #Catalog.All())
      assert.are.equal("level_10", Catalog.Get("level_10").id)
      assert.is_nil(Catalog.Get("nope"))
    end)

    it("indexes by criterion type", function()
      assert.are.equal(6, #Catalog.ByType("level"))
      assert.are.equal(4, #Catalog.ByType("account_level_count"))
      assert.is_true(#Catalog.ByType("death") > 0)
    end)

    it("indexes by category, exact and deep", function()
      assert.are.equal(6, #Catalog.ByCategory("general.level"))
      assert.are.equal(0, #Catalog.ByCategory("general"))
      local deep = 0
      for _, child in ipairs(Catalog.GetCategory("general").children) do
        deep = deep + #Catalog.ByCategory(child.id)
      end
      assert.are.equal(deep, #Catalog.ByCategory("general", true))
      assert.is_true(#Catalog.ByCategory("account", true) > 1)
      assert.are.equal(0, #Catalog.ByCategory("missing", true))
      assert.are.equal(#Catalog.ByCategory("general.misc"), #Catalog.ByCategory("general.misc", true))
    end)

    it("knows the dependents of an achievement", function()
      local dependents = Catalog.Dependents("level_10")
      assert.are.equal(1, #dependents)
      assert.are.equal("level_20", dependents[1].id)
      assert.are.equal(0, #Catalog.Dependents("level_60"))
    end)

    it("exposes the category tree", function()
      local roots = Catalog.Categories()
      assert.are.equal(9, #roots)
      assert.are.equal("general", roots[1].id)
      assert.are.equal("general", Catalog.GetCategory("general.level").parent)
      assert.is_nil(Catalog.GetCategory("nope"))
    end)

    it("rebuilds the indexes after a new registration", function()
      local before = #Catalog.ByType("death")
      fixture.Install(ns)
      assert.are.equal(before + 2, #Catalog.ByType("death"))
    end)

    it("resets", function()
      Catalog.Reset()
      assert.are.equal(0, Catalog.Count())
      assert.are.equal(0, #Catalog.Categories())
    end)

    it("builds the locale keys", function()
      assert.are.equal("ach.level_10.name", Catalog.NameKey("level_10"))
      assert.are.equal("ach.level_10.desc", Catalog.DescKey("level_10"))
    end)

    it("declares a mode or a derivation for every criterion type", function()
      for name, def in pairs(Catalog.CRITERIA_TYPES) do
        assert.is_true(
          def.mode == "max" or def.mode == "add" or def.derived == "meta" or def.derived == "account",
          name
        )
      end
    end)
  end)

  describe("real data", function()
    local ns, Catalog

    before_each(function()
      ns = Loader.Full()
      Catalog = ns.Catalog
    end)

    local function values(source, field)
      local set = {}
      for _, value in pairs(source) do
        set[field and value[field] or value] = true
      end
      return set
    end

    it("keeps every reference key inside the Data/Reference tables", function()
      local Ref = ns.Ref
      local known = {
        encounter = values(Ref.Encounters),
        explore_zone = values(Ref.Zones, "map"),
        skill = values(Ref.SkillLines),
        reputation = values(Ref.Factions),
        quest_id = values(Ref.Quests),
        bg_win = values(Ref.Battlegrounds),
        bg_played = values(Ref.Battlegrounds),
        item_obtained = values(Ref.Items),
      }
      local totals = {}
      for _, zone in pairs(Ref.Zones) do
        totals[zone.map] = zone.total
      end
      local critters = values(Ref.Critters)
      for _, ach in ipairs(Catalog.All()) do
        for _, criterion in ipairs(ach.criteria) do
          local set = known[criterion.type]
          if set then
            assert.is_true(set[criterion.key] == true, ach.id .. " uses an unknown " .. criterion.type .. " key")
          end
          if criterion.type == "explore_zone" then
            assert.are.equal(totals[criterion.key], criterion.total, ach.id .. " zone total")
            assert.are.equal(100, criterion.value, ach.id)
          elseif criterion.type == "emote_target" then
            local npc = tonumber(tostring(criterion.key):match(":(%d+)$"))
            assert.is_true(critters[npc] == true, ach.id .. " uses an unknown critter")
          end
        end
      end
    end)

    it("has the full catalog and no empty category", function()
      assert.is_true(Catalog.Count() >= 400)
      local function walk(nodes)
        for _, node in ipairs(nodes) do
          assert.is_true(#Catalog.ByCategory(node.id, true) > 0, "category " .. node.id .. " is empty")
          walk(node.children)
        end
      end
      walk(Catalog.Categories())
    end)

    it("does not use criterion types without a reliable source", function()
      for _, banned in ipairs({ "zone_quests", "explore_area", "pvp_rank" }) do
        assert.are.equal(0, #Catalog.ByType(banned), banned)
      end
    end)
  end)

  describe("Validate", function()
    local ns, Catalog

    -- A valid achievement plus its strings; each test breaks one thing.
    local function good(extra)
      local def = {
        id = "x_ok",
        category = "general.misc",
        points = 10,
        scope = "character",
        icon = 1,
        ref = {},
        criteria = { { type = "level", value = 5 } },
      }
      for key, value in pairs(extra or {}) do
        def[key] = value
      end
      return def
    end

    local function strings(id)
      ns.Locale.Register("enUS", { ["ach." .. id .. ".name"] = "N", ["ach." .. id .. ".desc"] = "D" })
      ns.Locale.Register("esES", { ["ach." .. id .. ".name"] = "N", ["ach." .. id .. ".desc"] = "D" })
    end

    local function check(...)
      for _, def in ipairs({ ... }) do
        if def.id then
          strings(def.id)
        end
      end
      Catalog.Reset()
      Catalog.RegisterCategories({
        { id = "general", name = "cat.general", children = { { id = "general.misc", name = "cat.general.misc" } } },
      })
      Catalog.Register({ ... })
      return rules(Catalog.Validate())
    end

    before_each(function()
      ns = Loader.Load(Loader.CORE, Loader.DOMAIN)
      Catalog = ns.Catalog
    end)

    it("accepts the real data plus the test catalog", function()
      ns = Loader.Full()
      fixture.Install(ns)
      local errors = ns.Catalog.Validate()
      local messages = {}
      for _, err in ipairs(errors) do
        messages[#messages + 1] = err.message
      end
      assert.are.same({}, messages)
      assert.is_true(ns.Catalog.Count() > 40)
    end)

    it("accepts a minimal valid achievement", function()
      assert.are.same({}, check(good()))
    end)

    it("rejects a duplicate id", function()
      assert.are.equal(1, check(good(), good()).duplicate_id)
    end)

    it("rejects a missing id", function()
      assert.are.equal(1, check(good({ id = false })).missing_id)
    end)

    it("rejects an unknown category", function()
      assert.are.equal(1, check(good({ category = "nope" })).unknown_category)
    end)

    it("rejects an unknown criterion type", function()
      assert.are.equal(1, check(good({ criteria = { { type = "telepathy", value = 1 } } })).unknown_criterion_type)
    end)

    it("rejects a previous that does not exist", function()
      assert.are.equal(1, check(good({ previous = "ghost" })).missing_previous)
    end)

    it("rejects a meta criterion that points nowhere", function()
      local def = good({ criteria = { { type = "meta", key = "ghost" } } })
      assert.are.equal(1, check(def).missing_meta)
    end)

    it("rejects a previous cycle", function()
      local found = check(good({ id = "a", previous = "b" }), good({ id = "b", previous = "a" }))
      assert.are.equal(1, found.cycle)
    end)

    it("rejects a meta cycle and a self reference", function()
      local a = good({ id = "a", criteria = { { type = "meta", key = "b" } } })
      local b = good({ id = "b", criteria = { { type = "meta", key = "a" } } })
      assert.are.equal(1, check(a, b).cycle)
      assert.are.equal(1, check(good({ id = "s", previous = "s" })).cycle)
    end)

    it("rejects points outside the allowed set", function()
      assert.are.equal(1, check(good({ points = 7 })).invalid_points)
      assert.are.equal(1, check(good({ points = "ten" })).invalid_points)
    end)

    it("accepts every allowed point value", function()
      for _, points in ipairs({ 0, 5, 10, 15, 20, 25, 50 }) do
        assert.are.same({}, check(good({ points = points })))
      end
    end)

    it("requires a feat of strength to have 0 points", function()
      assert.are.equal(1, check(good({ feat = true, points = 10 })).feat_points)
      assert.are.same({}, check(good({ feat = true, points = 0 })))
    end)

    it("rejects an invalid scope", function()
      assert.are.equal(1, check(good({ scope = "guild" })).invalid_scope)
    end)

    it("rejects an invalid faction", function()
      assert.are.equal(1, check(good({ faction = "Neutral" })).invalid_faction)
      assert.are.same({}, check(good({ faction = "Horde" })))
    end)

    it("rejects a chain that mixes factions", function()
      local first = good({ id = "a", faction = "Horde" })
      local second = good({ id = "b", faction = "Alliance", previous = "a" })
      assert.are.equal(1, check(first, second).faction_mismatch)
    end)

    it("rejects an achievement without criteria", function()
      assert.are.equal(1, check(good({ criteria = {} })).no_criteria)
      assert.are.equal(1, check(good({ criteria = false })).no_criteria)
    end)

    it("rejects an invalid require", function()
      assert.are.equal(1, check(good({ require = 3 })).invalid_require)
      assert.are.equal(1, check(good({ require = "some" })).invalid_require)
      assert.are.same({}, check(good({ require = 1 })))
      assert.are.same({}, check(good({ require = "all" })))
    end)

    it("keeps account scope to derived criteria", function()
      assert.are.equal(1, check(good({ scope = "account" })).account_scope_type)
      assert.are.equal(1, check(good({ criteria = { { type = "account_money", value = 1 } } })).character_scope_type)
    end)

    it("rejects a missing name or description in either locale", function()
      local def = good()
      strings(def.id)
      ns.Locale.Get("enUS")["ach.x_ok.name"] = nil
      ns.Locale.Get("esES")["ach.x_ok.desc"] = ""
      Catalog.Reset()
      Catalog.RegisterCategories({
        { id = "general", name = "cat.general", children = { { id = "general.misc", name = "cat.general.misc" } } },
      })
      Catalog.Register({ def })
      local found = rules(Catalog.Validate())
      assert.are.equal(1, found.missing_name)
      assert.are.equal(1, found.missing_desc)
    end)

    it("rejects a category whose name is missing in a locale", function()
      Catalog.Reset()
      Catalog.RegisterCategories({ { id = "ghost", name = "cat.ghost" } })
      assert.are.equal(2, rules(Catalog.Validate()).missing_category_name)
    end)
  end)
end)

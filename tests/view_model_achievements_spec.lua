local UiHarness = dofile("tests/support/ui_harness.lua")

describe("ViewModelAchievements", function()
  local h, VMA

  before_each(function()
    h = UiHarness.Build()
    h.ns.Locale.Use("enUS")
    VMA = h.ns.ViewModelAchievements
    h.store:GetCharacter("Player-2", { name = "Warlock", class = "WARLOCK", faction = "Horde", level = 20 })
  end)

  local function ids(rows)
    local list = {}
    for index, row in ipairs(rows) do
      list[index] = row.id
    end
    return list
  end

  local function has(rows, id)
    for _, row in ipairs(rows) do
      if row.id == id then
        return row
      end
    end
    return nil
  end

  local function find(nodes, id)
    for _, node in ipairs(nodes) do
      if node.id == id then
        return node
      end
      local inner = find(node.children, id)
      if inner then
        return inner
      end
    end
    return nil
  end

  describe("context", function()
    it("defaults to the character view and reads the guid", function()
      local ctx = VMA.Context(h.app, "nonsense")
      assert.are.equal("character", ctx.mode)
      assert.are.equal("Player-1", ctx.guid)
      assert.are.equal("account", VMA.Context(h.app, "account").mode)
    end)
  end)

  describe("tree", function()
    it("counts earned and total per category, deeply, and prunes empty ones", function()
      h.give("Player-1", "t_level", 100)
      local tree = VMA.Tree(h.ctx("character"))
      local general = find(tree, "general")
      local misc = find(tree, "general.misc")
      assert.is_not_nil(general)
      assert.are.equal(misc.total, general.total)
      assert.are.equal(1, misc.earned)
      assert.are.equal(VMA.Totals(h.ctx("character")).total, misc.total + find(tree, "feats").total)
      assert.is_nil(find(tree, "general.wealth"))
      -- Character view never lists the account category.
      assert.is_nil(find(tree, "account"))
      assert.are.equal(string.format("%d/%d", 1, misc.total), misc.text)
      assert.is_true(misc.fraction > 0 and misc.fraction < 1)
    end)

    it("excludes hidden unearned and other-faction achievements from the totals", function()
      local ctx = h.ctx("character")
      local base = find(VMA.Tree(ctx), "general.misc").total
      local all = 0
      for _, ach in ipairs(h.ns.Catalog.ByCategory("general.misc")) do
        all = all + 1
        assert.is_not_nil(ach)
      end
      -- t_hidden and t_horde_only are not counted for an Alliance character.
      assert.are.equal(all - 2, base)
      h.give("Player-1", "t_hidden", 5)
      assert.are.equal(base + 1, find(VMA.Tree(h.ctx("character")), "general.misc").total)
    end)

    it("includes the account category and every character achievement in the account view", function()
      local tree = VMA.Tree(h.ctx("account"))
      assert.is_not_nil(find(tree, "account"))
      assert.is_not_nil(find(tree, "account.general"))
      local totals = VMA.Totals(h.ctx("account"))
      assert.is_true(totals.total > VMA.Totals(h.ctx("character")).total)
    end)

    it("is zero-safe without characters or categories", function()
      h.guid = nil
      local totals = VMA.Totals(h.ctx("character"))
      assert.is_true(totals.total >= 0)
      assert.is_true(totals.fraction >= 0 and totals.fraction <= 1)
    end)
  end)

  describe("rows", function()
    it("builds a full row for an earned and an unearned achievement", function()
      h.give("Player-1", "t_level", os.time({ year = 2026, month = 11, day = 5, hour = 12 }))
      local rows = VMA.Rows(h.ctx("character"), { category = "general.misc" })
      local earned = has(rows, "t_level")
      assert.is_true(earned.earned)
      assert.are.equal("Test t_level", earned.name)
      assert.are.equal("Test description of t_level", earned.desc)
      assert.are.equal("5", earned.pointsText)
      assert.are.equal("05/11/26", earned.dateText)
      assert.are.equal(1, earned.fraction)
      assert.are.equal(134400, earned.icon)
      assert.is_false(earned.canTrack)
      local open = has(rows, "t_money")
      assert.is_false(open.earned)
      assert.are.equal("", open.dateText)
      assert.are.equal("0c / 10s", open.progressText)
      assert.is_true(open.canTrack)
    end)

    it("shows 'Earned before the addon' for retro grants", function()
      h.give("Player-1", "t_level", 100, true)
      local row = has(VMA.Rows(h.ctx("character"), {}), "t_level")
      assert.is_true(row.retro)
      assert.are.equal("Earned before the addon", row.dateText)
    end)

    it("filters by category including subcategories", function()
      local feats = VMA.Rows(h.ctx("character"), { category = "feats" })
      assert.are.same({ "t_feat" }, ids(feats))
      local misc = VMA.Rows(h.ctx("character"), { category = "general.misc" })
      assert.is_nil(has(misc, "t_feat"))
      local general = VMA.Rows(h.ctx("character"), { category = "general" })
      assert.are.equal(#misc, #general)
      assert.are.same({}, VMA.Rows(h.ctx("character"), { category = "nope" }))
    end)

    it("filters by status", function()
      h.give("Player-1", "t_level", 100)
      local ctx = h.ctx("character")
      local all = VMA.Rows(ctx, { status = "all" })
      local done = VMA.Rows(ctx, { status = "completed" })
      local todo = VMA.Rows(ctx, { status = "incomplete" })
      assert.are.same({ "t_level" }, ids(done))
      assert.are.equal(#all - 1, #todo)
      assert.are.equal(#all, #VMA.Rows(ctx, {}))
    end)

    it("searches names and descriptions ignoring case and accents, across categories", function()
      h.ns.Locale.Register("enUS", {
        ["ach.t_level.name"] = "Exploración Épica",
        ["ach.t_money.desc"] = "Reúne ORO",
      })
      local ctx = h.ctx("character")
      assert.are.same({ "t_level" }, ids(VMA.Rows(ctx, { search = "exploracion epica" })))
      assert.are.same({ "t_level" }, ids(VMA.Rows(ctx, { search = "  EXPLORACIÓN " })))
      assert.are.same({ "t_money" }, ids(VMA.Rows(ctx, { search = "reune oro" })))
      -- The category is ignored while there is a search text.
      assert.are.same({ "t_level" }, ids(VMA.Rows(ctx, { search = "epica", category = "feats" })))
      assert.are.same({}, ids(VMA.Rows(ctx, { search = "zzzz" })))
      assert.are.same({ "t_level" }, ids(VMA.Rows(ctx, { search = "epica", status = "incomplete" })))
      assert.are.same({}, ids(VMA.Rows(ctx, { search = "epica", status = "completed" })))
    end)

    it("shows only the next step of a chain", function()
      local ctx = h.ctx("character")
      local rows = VMA.Rows(ctx, { category = "general.misc" })
      assert.is_not_nil(has(rows, "t_chain_1"))
      assert.is_nil(has(rows, "t_chain_2"))
      assert.is_nil(has(rows, "t_chain_3"))
      h.give("Player-1", "t_chain_1", 10)
      rows = VMA.Rows(h.ctx("character"), { category = "general.misc" })
      assert.is_not_nil(has(rows, "t_chain_1"))
      assert.is_not_nil(has(rows, "t_chain_2"))
      assert.is_nil(has(rows, "t_chain_3"))
    end)

    it("hides hidden achievements until they are earned", function()
      assert.is_nil(has(VMA.Rows(h.ctx("character"), {}), "t_hidden"))
      h.give("Player-1", "t_hidden", 10)
      assert.is_not_nil(has(VMA.Rows(h.ctx("character"), {}), "t_hidden"))
    end)

    it("hides achievements of the other faction", function()
      local rows = VMA.Rows(h.ctx("character"), {})
      assert.is_not_nil(has(rows, "t_alliance_only"))
      assert.is_nil(has(rows, "t_horde_only"))
      h.guid = "Player-2"
      rows = VMA.Rows(h.ctx("character"), {})
      assert.is_nil(has(rows, "t_alliance_only"))
      assert.is_not_nil(has(rows, "t_horde_only"))
    end)

    it("shows feats with no points", function()
      local feat = has(VMA.Rows(h.ctx("character"), { category = "feats" }), "t_feat")
      assert.is_true(feat.feat)
      assert.are.equal("", feat.pointsText)
      assert.are.equal(0, feat.points)
    end)

    it("flags tracked achievements", function()
      h.tracker:Track("t_money")
      local rows = VMA.Rows(h.ctx("character"), { category = "general.misc" })
      assert.is_true(has(rows, "t_money").tracked)
      assert.is_false(has(rows, "t_level").tracked)
    end)

    it("shows the progress of a multi-criterion achievement as a fraction", function()
      h.feed("quest_id", 1, 1)
      local row = has(VMA.Rows(h.ctx("character"), {}), "t_nofm")
      assert.are.equal("1/2", row.progressText)
      assert.is_true(row.fraction > 0)
    end)

    it("cuts very long results and says so", function()
      local _, whole = VMA.Rows(h.ctx("character"), {})
      assert.is_false(whole)
      local old = VMA.ROW_LIMIT
      VMA.ROW_LIMIT = 3
      local rows, truncated = VMA.Rows(h.ctx("character"), {})
      VMA.ROW_LIMIT = old
      assert.are.equal(3, #rows)
      assert.is_true(truncated)
    end)

    it("copes with a missing current character", function()
      h.guid = nil
      local rows = VMA.Rows(h.ctx("character"), {})
      assert.is_true(#rows > 0)
      assert.is_false(rows[1].earned)
      assert.are.equal(0, rows[1].fraction)
      -- Faction achievements need a character.
      assert.is_nil(has(rows, "t_alliance_only"))
    end)
  end)

  describe("account view", function()
    it("shows who earned a character achievement first, and when", function()
      local day1 = os.time({ year = 2026, month = 11, day = 5, hour = 12 })
      local day2 = os.time({ year = 2026, month = 11, day = 7, hour = 12 })
      h.give("Player-1", "t_level", day2)
      h.give("Player-2", "t_level", day1)
      local row = has(VMA.Rows(h.ctx("account"), {}), "t_level")
      assert.is_true(row.earned)
      assert.are.equal("Earned by Warlock on 05/11/26", row.dateText)
      -- The character view only knows the current character.
      assert.are.equal("07/11/26", has(VMA.Rows(h.ctx("character"), {}), "t_level").dateText)
    end)

    it("uses the retro label and breaks ties by guid", function()
      h.give("Player-1", "t_level", 50, true)
      h.give("Player-2", "t_level", 50, true)
      local row = has(VMA.Rows(h.ctx("account"), {}), "t_level")
      assert.are.equal("Earned by Hero before the addon", row.dateText)
    end)

    it("lists account achievements with the character that triggered them", function()
      h.store:AccountEarned().t_acc_levels = { at = 10, retro = false, by = "Player-2" }
      h.store:AccountEarned().t_acc_money = { at = 10, retro = false }
      local rows = VMA.Rows(h.ctx("account"), { category = "account.general" })
      assert.are.equal("Earned by Warlock on " .. h.ns.ViewModel.FormatDate(10), has(rows, "t_acc_levels").dateText)
      assert.are.equal(h.ns.ViewModel.FormatDate(10), has(rows, "t_acc_money").dateText)
      assert.is_false(has(rows, "t_acc_classes").earned)
      -- The meta account achievement depends on a hidden one: shown, since it is not hidden itself.
      assert.is_not_nil(has(rows, "t_acc_meta"))
    end)

    it("applies the faction rule to the whole account", function()
      local rows = VMA.Rows(h.ctx("account"), {})
      assert.is_not_nil(has(rows, "t_horde_only"))
      assert.is_not_nil(has(rows, "t_alliance_only"))
      h.store:Forget("Player-2")
      rows = VMA.Rows(h.ctx("account"), {})
      assert.is_nil(has(rows, "t_horde_only"))
      h.store:Forget("Player-1")
      rows = VMA.Rows(h.ctx("account"), {})
      assert.is_not_nil(has(rows, "t_horde_only"))
    end)

    it("shows a hidden achievement once anyone earned it and applies chains account-wide", function()
      assert.is_nil(has(VMA.Rows(h.ctx("account"), {}), "t_hidden"))
      h.give("Player-2", "t_hidden", 3)
      assert.is_not_nil(has(VMA.Rows(h.ctx("account"), {}), "t_hidden"))
      assert.is_nil(has(VMA.Rows(h.ctx("account"), {}), "t_chain_2"))
      h.give("Player-2", "t_chain_1", 3)
      assert.is_not_nil(has(VMA.Rows(h.ctx("account"), {}), "t_chain_2"))
    end)

    it("shows the best progress of any character for an unearned achievement", function()
      h.store:Progress("Player-2").quest_count = 3
      local row = has(VMA.Rows(h.ctx("account"), {}), "t_quest_count")
      assert.is_false(row.earned)
      assert.is_true(row.fraction > 0.5)
      assert.are.equal("3 / 5", row.progressText)
    end)
  end)

  describe("points", function()
    it("sums the current character's points in the character view", function()
      h.give("Player-1", "t_level", 1)
      h.give("Player-1", "t_feat", 1)
      h.give("Player-2", "t_money", 1)
      assert.are.equal(5, VMA.Points(h.ctx("character")))
      h.guid = nil
      assert.are.equal(0, VMA.Points(h.ctx("character")))
    end)

    it("sums every character plus the account achievements in the account view", function()
      h.give("Player-1", "t_level", 1)
      h.give("Player-2", "t_money", 1)
      h.store:AccountEarned().t_acc_levels = { at = 1 }
      assert.are.equal(15, VMA.Points(h.ctx("account")))
    end)
  end)

  describe("criteria", function()
    it("returns nil for an unknown achievement", function()
      assert.is_nil(VMA.Criteria(h.ctx("character"), "nope"))
    end)

    it("shows current/required per criterion for an open achievement", function()
      h.feed("quest_id", 1, 1)
      local criteria = VMA.Criteria(h.ctx("character"), "t_nofm")
      assert.are.equal(3, #criteria.rows)
      assert.is_true(criteria.rows[1].done)
      assert.is_false(criteria.rows[2].done)
      assert.are.equal(1, criteria.completed)
      assert.are.equal(2, criteria.required)
      assert.are.equal("1/2", criteria.summary)
      assert.are.equal("Complete the quest", criteria.rows[1].text)
    end)

    it("formats money and time criteria", function()
      h.feed("money", 500)
      local money = VMA.Criteria(h.ctx("character"), "t_money").rows[1]
      assert.are.equal("5s / 10s", money.valueText)
      local played = VMA.Criteria(h.ctx("character"), "t_played").rows[1]
      assert.are.equal("0m / 1h 0m", played.valueText)
    end)

    it("marks every criterion done for an earned achievement", function()
      h.give("Player-1", "t_nofm", 1)
      local criteria = VMA.Criteria(h.ctx("character"), "t_nofm")
      for _, row in ipairs(criteria.rows) do
        assert.is_true(row.done)
        assert.are.equal(1, row.fraction)
      end
      assert.are.equal(1, criteria.fraction)
      assert.is_nil(VMA.Criteria(h.ctx("character"), "t_level").summary)
    end)

    it("names a meta criterion after the achievement it needs and honours custom criterion texts", function()
      local meta = VMA.Criteria(h.ctx("character"), "t_meta")
      assert.are.equal("Test t_bg_win", meta.rows[1].text)
      h.ns.Locale.Register("enUS", { ["ach.t_level.c1"] = "Reach level ten" })
      assert.are.equal("Reach level ten", VMA.Criteria(h.ctx("character"), "t_level").rows[1].text)
    end)

    it("falls back to zero progress when the engine cannot answer", function()
      h.guid = nil
      local criteria = VMA.Criteria(h.ctx("character"), "t_level")
      assert.are.equal(0, criteria.fraction)
      assert.is_false(criteria.rows[1].done)
    end)

    it("uses the best character in the account view", function()
      h.store:Progress("Player-2").level = 10
      local criteria = VMA.Criteria(h.ctx("account"), "t_level")
      assert.is_true(criteria.rows[1].done)
    end)
  end)

  describe("row and tracked", function()
    it("builds one row by id", function()
      assert.is_nil(VMA.Row(h.ctx("character"), "nope"))
      assert.are.equal("t_level", VMA.Row(h.ctx("character"), "t_level").id)
    end)

    it("lists tracked achievements with their progress", function()
      h.feed("quest_count", 2)
      h.feed("quest_id", 1, 1)
      local rows = VMA.Tracked(h.ctx("character"), { "t_quest_count", "missing", "t_nofm", "t_level" })
      assert.are.equal(3, #rows)
      assert.are.equal("t_quest_count", rows[1].id)
      assert.are.equal("2 / 5", rows[1].progressText)
      assert.are.equal("1/2", rows[2].progressText)
      assert.is_false(rows[1].earned)
      h.guid = nil
      assert.are.equal(0, VMA.Tracked(h.ctx("character"), { "t_level" })[1].fraction)
    end)
  end)
end)

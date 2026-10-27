local Harness = dofile("tests/support/harness.lua")

describe("CriteriaEngine", function()
  local h

  before_each(function()
    h = Harness.Build()
  end)

  describe("progress modes", function()
    it("keeps the maximum for max types", function()
      h.feed("level", 5)
      h.feed("level", 3)
      assert.are.equal(5, h.store:Progress("Player-1").level)
      h.feed("money", 400)
      h.feed("money", 900)
      h.feed("money", 100)
      assert.are.equal(900, h.store:Progress("Player-1").money)
    end)

    it("increments counters for add types", function()
      h.feed("death", 1)
      h.feed("death", 1)
      assert.are.equal(2, h.store:Progress("Player-1").death)
      assert.is_nil(h.earned("t_death"))
      h.feed("death", 1)
      assert.is_not_nil(h.earned("t_death"))
    end)

    it("keeps one progress value per key", function()
      h.feed("reputation", 1000, 72)
      h.feed("reputation", 500, 73)
      assert.are.equal(1000, h.store:Progress("Player-1")["reputation:72"])
      assert.are.equal(500, h.store:Progress("Player-1")["reputation:73"])
      h.feed("reputation", 42000, 72)
      assert.is_not_nil(h.earned("t_reputation"))
    end)

    it("ignores unknown types, derived types, bad values and a missing character", function()
      assert.are.equal(0, h.feed("telepathy", 5))
      assert.are.equal(0, h.feed("meta", 1, "t_death"))
      assert.are.equal(0, h.feed("account_money", 99999))
      assert.are.equal(0, h.feed("level", "ten"))
      h.guid = nil
      assert.are.equal(0, h.feed("level", 99))
      assert.are.same({}, h.store:Progress("Player-1"))
    end)

    it("publishes progress.changed only when the value changes", function()
      local changes = {}
      h.bus:Subscribe("progress.changed", function(event)
        changes[#changes + 1] = event
      end)
      h.feed("level", 4)
      h.feed("level", 4)
      h.feed("level", 2)
      assert.are.equal(1, #changes)
      assert.are.equal("level", changes[1].type)
      assert.are.equal(4, changes[1].value)
      assert.are.equal("Player-1", changes[1].guid)
    end)

    it("works without a bus", function()
      h.engine.bus = nil
      assert.has_no.errors(function()
        h.feed("level", 4)
      end)
    end)

    it("evaluates only the achievements of the fact type", function()
      h.feed("level", 10)
      assert.is_not_nil(h.earned("t_level"))
      assert.is_nil(h.earned("t_money"))
      assert.are.same({ "t_level" }, h.ids())
    end)

    it("evaluates achievements added after the progress was stored", function()
      h.feed("quest_count", 7)
      h.ns.Locale.Register("enUS", { ["ach.t_late.name"] = "n", ["ach.t_late.desc"] = "d" })
      h.ns.Catalog.Register({
        {
          id = "t_late",
          category = "general.misc",
          points = 5,
          scope = "character",
          criteria = { { type = "quest_count", value = 6 } },
        },
      })
      h.feed("quest_count", 7)
      assert.is_not_nil(h.earned("t_late"))
    end)
  end)

  describe("require", function()
    it('needs every criterion for "all" (meta over two achievements)', function()
      h.feed("bg_win", 3)
      assert.is_nil(h.earned("t_meta"))
      h.feed("bg_played", 3)
      assert.is_not_nil(h.earned("t_meta"))
    end)

    it("needs n of m", function()
      h.feed("quest_id", 1, 1)
      assert.is_nil(h.earned("t_nofm"))
      h.feed("quest_id", 1, 3)
      assert.is_not_nil(h.earned("t_nofm"))
    end)

    it("does not award an achievement without criteria", function()
      h.ns.Catalog.Register({
        { id = "t_empty", category = "general.misc", points = 5, scope = "character", criteria = {} },
      })
      assert.has_no.errors(function()
        h.engine:EvaluateType("level")
        h.engine:Evaluate(h.ns.Catalog.Get("t_empty"), "Player-1")
      end)
      assert.is_nil(h.earned("t_empty"))
    end)
  end)

  describe("chains", function()
    it("never skips a step: the next one waits for the previous", function()
      h.feed("death", 2)
      h.feed("level", 35)
      assert.is_nil(h.earned("t_chain_2"))
      assert.is_nil(h.earned("t_chain_3"))
      assert.is_false(h.engine:IsVisible(h.ns.Catalog.Get("t_chain_2"), "Player-1"))
    end)

    it("earning a step catches up the next ones in order", function()
      h.feed("death", 2)
      h.feed("level", 35)
      h.events = {}
      assert.is_true(h.feed("quest_count", 1) >= 3)
      local chain = {}
      for _, id in ipairs(h.ids()) do
        if id:find("^t_chain_") then
          chain[#chain + 1] = id
        end
      end
      assert.are.same({ "t_chain_1", "t_chain_2", "t_chain_3" }, chain)
    end)

    it("only shows the next step once the previous one is earned", function()
      local second = h.ns.Catalog.Get("t_chain_2")
      assert.is_true(h.engine:IsVisible(h.ns.Catalog.Get("t_chain_1"), "Player-1"))
      assert.is_false(h.engine:IsVisible(second, "Player-1"))
      h.feed("quest_count", 1)
      assert.is_true(h.engine:IsVisible(second, "Player-1"))
    end)

    it("does not evaluate a step whose previous achievement is gone from the catalog", function()
      h.ns.Catalog.Register({
        {
          id = "t_orphan",
          category = "general.misc",
          points = 5,
          scope = "character",
          previous = "ghost",
          criteria = { { type = "level", value = 1 } },
        },
      })
      h.feed("level", 5)
      assert.is_nil(h.earned("t_orphan"))
      assert.is_false(h.engine:IsVisible(h.ns.Catalog.Get("t_orphan"), "Player-1"))
    end)
  end)

  describe("metas", function()
    it("cascades from a granted achievement to the meta that lists it", function()
      h.feed("death", 3)
      assert.is_not_nil(h.earned("t_meta_any"))
      assert.are.same({ "t_death", "t_meta_any" }, h.ids())
    end)

    it("lets an account meta see achievements earned by any character", function()
      h.feed("level", 13)
      assert.is_nil(h.store:AccountEarned().t_acc_meta)
      h.feed("level", 14)
      assert.is_not_nil(h.store:AccountEarned().t_acc_meta)
      assert.are.equal("Player-1", h.store:AccountEarned().t_acc_meta.by)
    end)

    it("does not count a meta target that does not exist", function()
      local meta = { type = "meta", key = "ghost" }
      assert.are.equal(0, h.engine:Current(meta, "Player-1", { scope = "character" }))
    end)
  end)

  describe("faction", function()
    it("evaluates only the achievements of the character's faction", function()
      h.feed("level", 12)
      assert.is_not_nil(h.earned("t_alliance_only"))
      assert.is_nil(h.earned("t_horde_only"))
    end)

    it("switches with the character", function()
      h.store:GetCharacter("Player-2", { faction = "Horde" })
      h.guid = "Player-2"
      h.feed("level", 12)
      assert.is_not_nil(h.earned("t_horde_only"))
      assert.is_nil(h.earned("t_alliance_only"))
    end)

    it("hides the other faction and a character without faction", function()
      local horde = h.ns.Catalog.Get("t_horde_only")
      assert.is_false(h.engine:Applies(horde, "Player-1"))
      assert.is_false(h.engine:IsVisible(horde, "Player-1"))
      assert.is_false(h.engine:Applies(horde, nil))
      assert.is_true(h.engine:Applies(h.ns.Catalog.Get("t_acc_money"), nil))
    end)
  end)

  describe("visibility", function()
    it("hides a hidden achievement until it is earned", function()
      local hidden = h.ns.Catalog.Get("t_hidden")
      assert.is_false(h.engine:IsVisible(hidden, "Player-1"))
      h.feed("level", 14)
      assert.is_true(h.engine:IsVisible(hidden, "Player-1"))
    end)
  end)

  describe("idempotency", function()
    it("awards once however many times the fact arrives", function()
      h.feed("level", 10)
      local at = h.earned("t_level").at
      h.time = 2000
      assert.are.equal(0, h.feed("level", 10))
      h.feed("level", 20)
      assert.are.equal(at, h.earned("t_level").at)
      local count = 0
      for _, id in ipairs(h.ids()) do
        if id == "t_level" then
          count = count + 1
        end
      end
      assert.are.equal(1, count)
    end)
  end)

  describe("retro", function()
    it("grants silently with the retro flag", function()
      local count = h.award:Silent(function()
        h.feed("level", 10)
      end)
      assert.are.equal(1, count)
      assert.is_true(h.earned("t_level").retro)
      assert.are.same({}, h.events)
    end)

    it("marks live grants as not retro", function()
      h.feed("level", 10)
      assert.is_false(h.earned("t_level").retro)
      assert.are.equal(1, #h.events)
    end)

    it("skips non retroactive achievements but keeps the progress", function()
      h.award:Silent(function()
        h.feed("quest_count", 2)
      end)
      assert.is_nil(h.earned("t_no_retro"))
      assert.are.equal(2, h.store:Progress("Player-1").quest_count)
      h.feed("quest_count", 2)
      assert.is_not_nil(h.earned("t_no_retro"))
      assert.is_false(h.earned("t_no_retro").retro)
    end)
  end)

  describe("GetProgress", function()
    it("returns nil for an unknown achievement", function()
      assert.is_nil(h.engine:GetProgress("ghost"))
    end)

    it("reports current and required per criterion and the fraction", function()
      h.feed("quest_count", 2)
      local progress = h.engine:GetProgress("t_quest_count")
      assert.is_false(progress.earned)
      assert.are.equal(1, #progress.criteria)
      assert.are.equal(2, progress.criteria[1].current)
      assert.are.equal(5, progress.criteria[1].required)
      assert.is_false(progress.criteria[1].done)
      assert.are.equal(0.4, progress.fraction)
      assert.are.equal(0, progress.completed)
      assert.are.equal(1, progress.required)
    end)

    it("caps the fraction at 1 and reports an earned achievement as full", function()
      h.feed("quest_count", 50)
      local progress = h.engine:GetProgress("t_quest_count")
      assert.is_true(progress.earned)
      assert.are.equal(1, progress.fraction)
      assert.are.equal(1, progress.criteria[1].fraction)
    end)

    it("averages the best n criteria for n-of-m", function()
      h.feed("quest_id", 1, 1)
      local progress = h.engine:GetProgress("t_nofm")
      assert.are.equal(3, #progress.criteria)
      assert.are.equal(1, progress.completed)
      assert.are.equal(2, progress.required)
      assert.are.equal(0.5, progress.fraction)
    end)

    it("uses the given GUID", function()
      h.store:GetCharacter("Player-2", {})
      h.store:Progress("Player-2").quest_count = 4
      assert.are.equal(0.8, h.engine:GetProgress("t_quest_count", "Player-2").fraction)
      assert.are.equal(0, h.engine:GetProgress("t_quest_count").fraction)
    end)

    it("never divides by zero", function()
      assert.are.equal(1, h.engine.Fraction(5, 0))
      assert.are.equal(1, h.engine.Fraction(0, 0))
      assert.are.equal(1, h.engine.Fraction(0, -3))
      assert.are.equal(0, h.engine.Fraction(-4, 10))
      h.ns.Catalog.Register({
        {
          id = "t_zero",
          category = "general.misc",
          points = 5,
          scope = "character",
          criteria = { { type = "level", value = 0 } },
        },
      })
      local progress
      assert.has_no.errors(function()
        progress = h.engine:GetProgress("t_zero")
      end)
      assert.are.equal(1, progress.fraction)
      assert.is_true(progress.criteria[1].done)
    end)

    it("handles an achievement with no criteria", function()
      h.ns.Catalog.Register({
        { id = "t_none", category = "general.misc", points = 5, scope = "character", criteria = {} },
      })
      local progress = h.engine:GetProgress("t_none")
      assert.are.equal(0, progress.fraction)
      assert.are.equal(0, progress.required)
    end)

    it("reads account criteria through the account service", function()
      h.account:Record("Player-1", { level = 60, class = "WARRIOR" })
      local progress = h.engine:GetProgress("t_acc_classes")
      assert.are.equal(1, progress.criteria[1].current)
      assert.are.equal(3, progress.criteria[1].required)
      h.engine.account = nil
      assert.are.equal(0, h.engine:GetProgress("t_acc_classes").criteria[1].current)
    end)
  end)
end)

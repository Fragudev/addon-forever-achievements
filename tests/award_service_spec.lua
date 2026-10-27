local Harness = dofile("tests/support/harness.lua")

describe("AwardService", function()
  local h

  before_each(function()
    h = Harness.Build()
  end)

  it("grants a character achievement with its date and publishes it", function()
    h.time = 1234
    local ok, entry = h.award:Grant("t_level")
    assert.is_true(ok)
    assert.are.same({ at = 1234, retro = false }, entry)
    assert.are.same(entry, h.store:Earned("Player-1").t_level)
    assert.are.equal(1, #h.events)
    local event = h.events[1]
    assert.are.equal("t_level", event.id)
    assert.are.equal("character", event.scope)
    assert.are.equal("Player-1", event.guid)
    assert.are.equal(1234, event.at)
    assert.are.equal(5, event.points)
    assert.is_false(event.retro)
    assert.is_false(event.feat)
    assert.are.equal("t_level", event.achievement.id)
  end)

  it("is idempotent", function()
    h.award:Grant("t_level")
    h.time = 9999
    local ok, reason = h.award:Grant("t_level")
    assert.is_false(ok)
    assert.are.equal("already", reason)
    assert.are.equal(1000, h.earned("t_level").at)
    assert.are.equal(1, #h.events)
    assert.are.equal(1, h.award:Total())
  end)

  it("refuses an unknown achievement and a missing character", function()
    local ok, reason = h.award:Grant("ghost")
    assert.is_false(ok)
    assert.are.equal("unknown", reason)
    h.guid = nil
    ok, reason = h.award:Grant("t_level")
    assert.is_false(ok)
    assert.are.equal("no_character", reason)
  end)

  it("grants an account achievement to the account with the character in `by`", function()
    local ok, entry = h.award:Grant("t_acc_money")
    assert.is_true(ok)
    assert.are.same({ at = 1000, retro = false, by = "Player-1" }, entry)
    assert.are.same(entry, h.store:AccountEarned().t_acc_money)
    assert.is_nil(h.earned("t_acc_money"))
    assert.are.equal("account", h.events[1].scope)
    h.guid = nil
    h.award:Grant("t_acc_points")
    assert.is_nil(h.store:AccountEarned().t_acc_points.by)
  end)

  it("marks a grant retro on request without silencing it", function()
    local _, entry = h.award:Grant("t_level", { retro = true })
    assert.is_true(entry.retro)
    assert.are.equal(1, #h.events)
    assert.is_true(h.events[1].retro)
    assert.is_true(h.events[1].retro and not h.award:IsRetro())
  end)

  it("flags feats in the event", function()
    h.award:Grant("t_feat")
    assert.is_true(h.events[1].feat)
    assert.are.equal(0, h.events[1].points)
  end)

  it("works without a bus or an engine", function()
    h.award.bus = nil
    h.award.engine = nil
    assert.is_true(h.award:Grant("t_level"))
  end)

  describe("Silent", function()
    it("returns the number of grants, marks them retro and publishes nothing", function()
      local count = h.award:Silent(function()
        assert.is_true(h.award:IsRetro())
        h.award:Grant("t_level")
        h.award:Grant("t_money")
        h.award:Grant("t_money")
      end)
      assert.are.equal(2, count)
      assert.is_true(h.earned("t_level").retro)
      assert.are.same({}, h.events)
      assert.is_false(h.award:IsRetro())
    end)

    it("nests", function()
      local count = h.award:Silent(function()
        h.award:Silent(function()
          h.award:Grant("t_level")
        end)
        assert.is_true(h.award:IsRetro())
        h.award:Grant("t_money")
      end)
      assert.are.equal(2, count)
      assert.is_false(h.award:IsRetro())
    end)

    it("restores the mode and re-raises when the function fails", function()
      assert.has_error(function()
        h.award:Silent(function()
          error("boom", 0)
        end)
      end, "boom")
      assert.is_false(h.award:IsRetro())
    end)
  end)

  describe("cascade", function()
    local FIVE = { "t_level", "t_money", "t_played", "t_quest_count", "t_skill_count" }

    it("reevaluates the account point totals after a character grant", function()
      for index = 1, 4 do
        h.award:Grant(FIVE[index])
      end
      assert.is_nil(h.store:AccountEarned().t_acc_points)
      h.award:Grant(FIVE[5])
      assert.is_not_nil(h.store:AccountEarned().t_acc_points)
    end)

    it("does not count feats toward the account points", function()
      h.award:Grant("t_feat")
      for index = 1, 4 do
        h.award:Grant(FIVE[index])
      end
      assert.is_nil(h.store:AccountEarned().t_acc_points)
    end)

    it("does not count account achievements toward the account points", function()
      h.award:Grant("t_acc_money")
      h.award:Grant("t_acc_classes")
      h.award:Grant("t_acc_levels")
      for index = 1, 4 do
        h.award:Grant(FIVE[index])
      end
      assert.is_nil(h.store:AccountEarned().t_acc_points)
    end)
  end)
end)

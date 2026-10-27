local Env = dofile("tests/support/detector_env.lua")

describe("Quests detector", function()
  local env, det, completed

  before_each(function()
    env = Env.Build()
    completed = { 100, 200, 300, 400, 500, 500 }
    _G.C_QuestLog = {
      GetAllCompletedQuestIDs = function()
        return completed
      end,
    }
    det = env.add("Quests")
  end)

  after_each(function()
    env.close()
  end)

  local function fact(facts, factType, key)
    for _, candidate in ipairs(facts) do
      if candidate.type == factType and candidate.key == key then
        return candidate
      end
    end
    return nil
  end

  describe("retro provider", function()
    it("gives the distinct count and the referenced ids that are completed", function()
      local facts = det:Facts()
      assert.are.equal(5, fact(facts, "quest_count").value)
      assert.are.equal(1, fact(facts, "quest_id", 100).value)
      assert.is_nil(fact(facts, "quest_id", 1))
      assert.is_nil(fact(facts, "quest_id", 200))
    end)

    it("grants the quest achievements silently", function()
      det:Start()
      env.app.retro:Run()
      assert.is_true(env.h.earned("t_quest_count").retro)
      assert.is_true(env.h.earned("t_quest_id").retro)
      assert.is_nil(env.h.earned("t_no_retro"))
    end)

    it("ignores values that are not quest ids", function()
      completed = { 100, "x", 100 }
      assert.are.equal(1, fact(det:Facts(), "quest_count").value)
    end)

    it("gives nothing without the API or when it raises", function()
      _G.C_QuestLog = nil
      assert.are.same({}, det:Facts())
      _G.C_QuestLog = {
        GetAllCompletedQuestIDs = function()
          error("boom")
        end,
      }
      assert.are.same({}, det:Facts())
    end)
  end)

  describe("live", function()
    it("counts a newly turned-in quest and publishes its id when referenced", function()
      det:Start()
      env.fire(det, "QUEST_TURNED_IN", 1, 100, 5)
      assert.are.equal(6, env.h.store:Progress("Player-1").quest_count)
      assert.are.equal(1, env.h.store:Progress("Player-1")["quest_id:1"])
      assert.are.equal(1, env.app.stats:Get("quests_completed"))
    end)

    it("does not count a quest that was already completed", function()
      det:Start()
      env.fire(det, "QUEST_TURNED_IN", 200)
      env.fire(det, "QUEST_TURNED_IN", 200)
      assert.are.equal(5, env.h.store:Progress("Player-1").quest_count)
      assert.are.equal(2, env.app.stats:Get("quests_completed"))
    end)

    it("counts one new quest once", function()
      det:Start()
      env.fire(det, "QUEST_TURNED_IN", 777)
      env.fire(det, "QUEST_TURNED_IN", 777)
      assert.are.equal(6, env.h.store:Progress("Player-1").quest_count)
    end)

    it("publishes only the id when the completed list is unreadable", function()
      _G.C_QuestLog = nil
      det:Start()
      env.fire(det, "QUEST_TURNED_IN", 2)
      env.fire(det, "QUEST_TURNED_IN", 777)
      assert.is_nil(env.h.store:Progress("Player-1").quest_count)
      assert.are.equal(1, env.h.store:Progress("Player-1")["quest_id:2"])
    end)

    it("ignores an unreadable quest id", function()
      det:Start()
      env.fire(det, "QUEST_TURNED_IN", "x")
      env.fire(det, "QUEST_TURNED_IN")
      assert.are.equal(5, env.h.store:Progress("Player-1").quest_count or 5)
      assert.are.equal(0, env.app.stats:Get("quests_completed"))
    end)

    it("works without statistics", function()
      env.app.stats = nil
      det:Start()
      env.fire(det, "QUEST_TURNED_IN", 777)
      assert.are.equal(6, env.h.store:Progress("Player-1").quest_count)
    end)
  end)
end)

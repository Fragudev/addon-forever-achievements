local Env = dofile("tests/support/detector_env.lua")

describe("Reputation detector", function()
  local env, det, byId, rows

  before_each(function()
    env = Env.Build()
    byId = { [72] = { name = "Stormwind", factionID = 72, reaction = 8, currentStanding = 42500 } }
    rows = {
      { name = "Stormwind", factionID = 72, reaction = 8, currentStanding = 42500 },
      { name = "Ironforge", factionID = 47, reaction = 8, currentStanding = 42100 },
      { name = "Darnassus", factionID = 69, reaction = 6, currentStanding = 12000 },
      { name = "Header", reaction = 0 },
    }
    _G.C_Reputation = {
      GetFactionDataByID = function(id)
        return byId[id]
      end,
      GetNumFactions = function()
        return #rows
      end,
      GetFactionDataByIndex = function(index)
        return rows[index]
      end,
    }
    det = env.add("Reputation")
  end)

  after_each(function()
    env.close()
  end)

  local function byType(facts, factType, key)
    for _, fact in ipairs(facts) do
      if fact.type == factType and fact.key == key then
        return fact
      end
    end
    return nil
  end

  describe("retro provider", function()
    it("gives the standing of the referenced factions and the Exalted count", function()
      local facts = det:Facts()
      assert.are.equal(42500, byType(facts, "reputation", 72).value)
      assert.are.equal(2, byType(facts, "reputation_count").value)
    end)

    it("grants silently", function()
      det:Start()
      env.app.retro:Run()
      assert.is_true(env.h.earned("t_reputation").retro)
      assert.is_true(env.h.earned("t_reputation_count").retro)
    end)

    it("falls back to the legacy API", function()
      _G.C_Reputation = nil
      _G.GetFactionInfoByID = function(id)
        if id == 72 then
          return "Stormwind", "", 8, 42000, 43000, 42300
        end
      end
      _G.GetNumFactions = function()
        return 1
      end
      _G.GetFactionInfo = function()
        return "Stormwind", "", 8, 42000, 43000, 42300, false, false, false, false, true, false, false, 72
      end
      local facts = det:Facts()
      assert.are.equal(42300, byType(facts, "reputation", 72).value)
      assert.are.equal(1, byType(facts, "reputation_count").value)
    end)

    it("counts a referenced Exalted faction that the list hides", function()
      rows = {}
      assert.are.equal(1, byType(det:Facts(), "reputation_count").value)
    end)

    it("publishes nothing when no API answers or all of them raise", function()
      _G.C_Reputation = nil
      assert.are.same({}, det:Facts())
      _G.C_Reputation = {
        GetFactionDataByID = function()
          error("boom")
        end,
        GetNumFactions = function()
          error("boom")
        end,
      }
      assert.are.same({}, det:Facts())
    end)

    it("does not count a row without an id as a faction", function()
      byId = {}
      rows = { { name = "Odd", reaction = 8 } }
      assert.are.equal(0, byType(det:Facts(), "reputation_count").value)
    end)
  end)

  describe("live", function()
    it("re-reads on UPDATE_FACTION, coalesced, and updates the snapshot", function()
      env.add("Snapshot")
      env.useTimer()
      det:Start()
      env.fire(det, "UPDATE_FACTION")
      env.fire(det, "UPDATE_FACTION")
      env.fire(det, "UPDATE_FACTION")
      assert.are.equal(1, #env.timers)
      env.flush()
      assert.is_false(env.h.earned("t_reputation").retro)
      assert.are.equal(42500, env.h.store:Snapshot("Player-1").reps[72])
    end)

    it("owns the reps part of the snapshot", function()
      assert.are.same({ reps = { [72] = 42500 } }, det:SnapshotFields())
    end)
  end)
end)

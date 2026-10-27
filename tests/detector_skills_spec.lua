local Env = dofile("tests/support/detector_env.lua")

describe("Skills detector", function()
  local env, det, professions

  before_each(function()
    env = Env.Build()
    -- index -> { name, icon, rank, maxRank, abilities, offset, skillLine }
    professions = {
      [1] = { "Blacksmithing", 1, 300, 300, 0, 0, 164 },
      [2] = { "Herbalism", 1, 150, 150, 0, 0, 182 },
      [3] = { "Cooking", 1, 300, 300, 0, 0, 185 },
    }
    _G.GetProfessions = function()
      return 1, 2, nil, nil, 3
    end
    _G.GetProfessionInfo = function(index)
      local p = professions[index]
      if p then
        return unpack(p)
      end
    end
    env.ns.Catalog.Register({
      {
        id = "x_skill_164",
        category = "general.misc",
        points = 5,
        scope = "character",
        criteria = { { type = "skill", key = 164, value = 300 } },
      },
    })
    det = env.add("Skills")
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

  it("gives the referenced skill ranks and the count at the maximum", function()
    local facts = det:Facts()
    assert.are.equal(300, byType(facts, "skill", 164).value)
    assert.is_nil(byType(facts, "skill", 182))
    assert.are.equal(2, byType(facts, "skill_count").value)
  end)

  it("grants silently", function()
    det:Start()
    env.app.retro:Run()
    assert.is_true(env.h.earned("x_skill_164").retro)
    assert.is_true(env.h.earned("t_skill_count").retro)
  end)

  it("owns the skills part of the snapshot with every skill line", function()
    assert.are.same({ skills = { [164] = 300, [182] = 150, [185] = 300 } }, det:SnapshotFields())
  end)

  it("re-reads on SKILL_LINES_CHANGED, coalesced, and updates the snapshot", function()
    env.add("Snapshot")
    env.useTimer()
    det:Start()
    professions[2][3] = 300
    env.fire(det, "SKILL_LINES_CHANGED")
    env.fire(det, "SKILL_LINES_CHANGED")
    assert.are.equal(1, #env.timers)
    env.flush()
    assert.are.equal(3, env.h.store:Progress("Player-1").skill_count)
    assert.are.equal(300, env.h.store:Snapshot("Player-1").skills[182])
  end)

  it("skips a profession without a skill line but still counts it", function()
    professions[3][7] = nil
    assert.are.same({ [164] = 300, [182] = 150 }, det:SnapshotFields().skills)
    assert.are.equal(2, byType(det:Facts(), "skill_count").value)
  end)

  it("publishes nothing without the API, with no professions, or when it raises", function()
    _G.GetProfessions = nil
    assert.are.same({}, det:Facts())
    _G.GetProfessions = function() end
    assert.are.same({}, det:Facts())
    _G.GetProfessions = function()
      error("boom")
    end
    assert.are.same({}, det:Facts())
    _G.GetProfessions = function()
      return 1
    end
    _G.GetProfessionInfo = function()
      error("boom")
    end
    assert.are.same({}, det:Facts())
  end)
end)

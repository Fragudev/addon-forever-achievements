local Env = dofile("tests/support/detector_env.lua")

describe("Level detector", function()
  local env, det

  before_each(function()
    env = Env.Build()
    det = env.add("Level")
  end)

  after_each(function()
    env.close()
  end)

  it("answers the retro scan with the current level", function()
    _G.UnitLevel = function()
      return 60
    end
    assert.are.same({ { type = "level", value = 60 } }, det:Facts())
    det:Start()
    assert.are.equal(1, env.app.retro:Run() > 0 and 1 or 0)
    assert.is_true(env.h.earned("t_level").retro)
    assert.is_true(env.h.earned("t_alliance_only").retro)
    assert.is_nil(env.h.earned("t_horde_only"))
  end)

  it("publishes the level of PLAYER_LEVEL_UP, not the one UnitLevel still reports", function()
    _G.UnitLevel = function()
      return 9
    end
    det:Start()
    env.fire(det, "PLAYER_LEVEL_UP", 10)
    assert.is_false(env.h.earned("t_level").retro)
    assert.are.equal(10, env.h.store:Progress("Player-1").level)
    assert.are.equal(10, env.app.stats:Get("highest_level"))
  end)

  it("falls back to UnitLevel when the event argument is unusable", function()
    _G.UnitLevel = function()
      return 11
    end
    det:Start()
    env.fire(det, "PLAYER_LEVEL_UP", "x")
    assert.are.equal(11, env.h.store:Progress("Player-1").level)
  end)

  it("updates the character level in the snapshot", function()
    local snapshot = env.add("Snapshot")
    det:Start()
    env.fire(det, "PLAYER_LEVEL_UP", 12)
    assert.are.equal(12, env.h.store:FindCharacter("Player-1").level)
    assert.is_nil(snapshot.lastError)
  end)

  it("publishes nothing when the client gives no level", function()
    assert.are.same({}, det:Facts())
    det:Start()
    env.fire(det, "PLAYER_LEVEL_UP")
    assert.is_nil(env.h.store:Progress("Player-1").level)
  end)

  it("publishes nothing when the API raises or the level is a secret", function()
    _G.UnitLevel = function()
      error("boom")
    end
    assert.are.same({}, det:Facts())
    _G.UnitLevel = function()
      return 60
    end
    _G.issecretvalue = function()
      return true
    end
    assert.are.same({}, det:Facts())
  end)

  it("works without statistics", function()
    env.app.stats = nil
    det:Start()
    env.fire(det, "PLAYER_LEVEL_UP", 10)
    assert.is_not_nil(env.h.earned("t_level"))
  end)
end)

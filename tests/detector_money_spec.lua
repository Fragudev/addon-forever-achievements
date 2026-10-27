local Env = dofile("tests/support/detector_env.lua")

describe("Money detector", function()
  local env, det, copper

  before_each(function()
    env = Env.Build()
    copper = 1500
    _G.GetMoney = function()
      return copper
    end
    det = env.add("Money")
  end)

  after_each(function()
    env.close()
  end)

  it("answers the retro scan with the current money", function()
    assert.are.same({ { type = "money", value = 1500 } }, det:Facts())
    det:Start()
    env.app.retro:Run()
    assert.is_true(env.h.earned("t_money").retro)
  end)

  it("publishes on PLAYER_MONEY and queues the snapshot", function()
    local snapshot = env.add("Snapshot")
    env.useTimer()
    det:Start()
    copper = 20
    env.fire(det, "PLAYER_MONEY")
    copper = 2500
    env.fire(det, "PLAYER_MONEY")
    assert.are.equal(2500, env.h.store:Progress("Player-1").money)
    assert.is_false(env.h.earned("t_money").retro)
    -- The snapshot write is coalesced: one timer, one record, with the latest value.
    assert.are.equal(1, #env.timers)
    assert.are.equal(0, env.h.store:Snapshot("Player-1").money)
    env.flush()
    assert.are.equal(2500, env.h.store:Snapshot("Player-1").money)
    assert.is_nil(snapshot.lastError)
  end)

  it("owns the money part of the snapshot", function()
    assert.are.same({ money = 1500 }, det:SnapshotFields())
    _G.GetMoney = nil
    assert.is_nil(det:SnapshotFields())
  end)

  it("publishes nothing without the API or when it raises", function()
    _G.GetMoney = nil
    det:Start()
    env.fire(det, "PLAYER_MONEY")
    assert.are.same({}, det:Facts())
    assert.is_nil(env.h.store:Progress("Player-1").money)
    _G.GetMoney = function()
      error("boom")
    end
    assert.are.same({}, det:Facts())
  end)
end)

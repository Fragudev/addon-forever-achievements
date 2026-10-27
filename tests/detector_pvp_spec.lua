local Env = dofile("tests/support/detector_env.lua")

describe("PvP detector", function()
  local env, det, kills

  before_each(function()
    env = Env.Build()
    kills = 150
    _G.GetPVPLifetimeStats = function()
      return kills, 3, 0
    end
    det = env.add("PvP")
  end)

  after_each(function()
    env.close()
  end)

  it("answers the retro scan with the lifetime honourable kills", function()
    assert.are.same({ { type = "honor_kills", value = 150 } }, det:Facts())
    det:Start()
    env.app.retro:Run()
    assert.is_true(env.h.earned("t_honor_kills").retro)
  end)

  it("publishes on PLAYER_PVP_KILLS_CHANGED", function()
    kills = 99
    det:Start()
    env.fire(det, "PLAYER_PVP_KILLS_CHANGED")
    assert.is_nil(env.h.earned("t_honor_kills"))
    kills = 100
    env.fire(det, "PLAYER_PVP_KILLS_CHANGED")
    assert.is_false(env.h.earned("t_honor_kills").retro)
  end)

  it("publishes nothing without the API, when it raises or answers a secret", function()
    _G.GetPVPLifetimeStats = nil
    assert.are.same({}, det:Facts())
    _G.GetPVPLifetimeStats = function()
      error("boom")
    end
    assert.are.same({}, det:Facts())
    _G.GetPVPLifetimeStats = function()
      return 150
    end
    _G.issecretvalue = function()
      return true
    end
    assert.are.same({}, det:Facts())
  end)
end)

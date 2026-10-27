local Env = dofile("tests/support/detector_env.lua")

describe("Deaths detector", function()
  local env, det

  before_each(function()
    env = Env.Build()
    det = env.add("Deaths")
    det:Start()
  end)

  after_each(function()
    env.close()
  end)

  it("registers PLAYER_DEAD and has no retro answer", function()
    assert.are.same({ "PLAYER_DEAD" }, det.registration.registered)
    assert.are.same({}, det:Facts())
  end)

  it("adds one death per event, to the progress and the statistic", function()
    env.fire(det, "PLAYER_DEAD")
    env.fire(det, "PLAYER_DEAD")
    assert.are.equal(2, env.h.store:Progress("Player-1").death)
    assert.are.equal(2, env.app.stats:Get("deaths"))
    assert.is_nil(env.h.earned("t_death"))
    env.fire(det, "PLAYER_DEAD")
    assert.is_false(env.h.earned("t_death").retro)
  end)
end)

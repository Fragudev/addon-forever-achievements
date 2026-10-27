local Env = dofile("tests/support/detector_env.lua")

describe("Played detector", function()
  local env, det, requests

  before_each(function()
    env = Env.Build()
    requests = 0
    _G.RequestTimePlayed = function()
      requests = requests + 1
    end
    det = env.add("Played")
  end)

  after_each(function()
    env.close()
  end)

  it("asks for the time played once per session", function()
    det:Start()
    det:Start()
    assert.are.equal(1, requests)
  end)

  it("still starts when the client cannot be asked", function()
    _G.RequestTimePlayed = nil
    assert.has_no.errors(function()
      det:Start()
    end)
    assert.are.same({}, det:Facts())
    assert.is_nil(det:SnapshotFields())
  end)

  it("has no retro facts until the client has answered", function()
    det:Start()
    assert.are.same({}, det:Facts())
    assert.is_nil(det:SnapshotFields())
    assert.are.equal(0, env.app.retro:Run())
  end)

  it("treats the first answer as retroactive, with one summary line", function()
    det:Start()
    env.fire(det, "TIME_PLAYED_MSG", 7200, 100)
    assert.is_true(env.h.earned("t_played").retro)
    assert.are.equal(1, #env.said)
    assert.is_truthy(env.said[1]:find("1 achievement", 1, true))
    assert.are.same({ { type = "played", value = 7200 } }, det:Facts())
    assert.are.same({ played = 7200 }, det:SnapshotFields())
  end)

  it("treats later answers as live and stores them in the snapshot", function()
    env.add("Snapshot")
    det:Start()
    env.fire(det, "TIME_PLAYED_MSG", 100, 100)
    env.fire(det, "TIME_PLAYED_MSG", 7300, 100)
    assert.is_false(env.h.earned("t_played").retro)
    assert.are.equal(7300, env.h.store:Snapshot("Player-1").played)
  end)

  it("publishes plainly when the app has no retro feeder", function()
    env.app.FeedRetro = nil
    getmetatable(env.app).__index = {}
    det:Start()
    env.fire(det, "TIME_PLAYED_MSG", 7200, 1)
    assert.is_not_nil(env.h.earned("t_played"))
  end)

  it("ignores an unreadable answer", function()
    det:Start()
    env.fire(det, "TIME_PLAYED_MSG", "soon")
    env.fire(det, "TIME_PLAYED_MSG")
    assert.is_nil(env.h.store:Progress("Player-1").played)
  end)
end)

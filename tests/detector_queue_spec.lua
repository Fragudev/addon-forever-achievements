local Env = dofile("tests/support/detector_env.lua")

describe("Encounter lockdown queue", function()
  local env, det, queue, locked, inEncounter

  before_each(function()
    env = Env.Build()
    locked, inEncounter = false, false
    _G.C_ChatInfo = {
      InChatMessagingLockdown = function()
        return locked
      end,
    }
    _G.IsEncounterInProgress = function()
      return inEncounter
    end
    det = env.add("Level")
    queue = env.app.queue
  end)

  after_each(function()
    env.close()
  end)

  it("feeds the engine at once when nothing is locked", function()
    assert.is_false(queue:Locked())
    det:Publish({ { type = "level", value = 10 } })
    assert.is_not_nil(env.h.earned("t_level"))
    assert.are.equal(0, queue:Pending())
  end)

  it("parks facts during a chat lockdown or an encounter and returns 0", function()
    locked = true
    assert.is_true(queue:Locked())
    assert.are.equal(0, det:Publish({ { type = "level", value = 10 } }))
    assert.is_nil(env.h.earned("t_level"))
    assert.are.equal(1, queue:Pending())
    locked, inEncounter = false, true
    assert.is_true(queue:Locked())
    det:Publish({ { type = "money", value = 5 } })
    assert.are.equal(2, queue:Pending())
  end)

  it("treats an unknown lockdown state as open", function()
    _G.C_ChatInfo, _G.IsEncounterInProgress = nil, nil
    assert.is_false(queue:Locked())
  end)

  it("merges facts of the same type and key: add types sum, the others keep the highest", function()
    locked = true
    det:Publish({
      { type = "death", value = 1 },
      { type = "death", value = 1 },
      { type = "level", value = 5 },
      { type = "level", value = 12 },
      { type = "level", value = 7 },
      { type = "encounter", key = 1084, value = 1 },
      { type = "encounter", key = 1085, value = 1 },
    })
    assert.are.equal(4, queue:Pending())
    assert.are.equal(2, queue.facts[1].value)
    assert.are.equal(12, queue.facts[2].value)
  end)

  it("keeps the extra fields of the first fact and copies it", function()
    locked = true
    local fact = { type = "encounter", key = 1, value = 1, instanceType = "raid" }
    queue:Add(fact)
    fact.value = 99
    assert.are.equal(1, queue.facts[1].value)
    assert.are.equal("raid", queue.facts[1].instanceType)
  end)

  it("ignores facts without a numeric value", function()
    assert.is_false(queue:Add({ type = "level", value = "x" }))
    assert.is_false(queue:Add("level"))
    assert.are.equal(0, queue:Pending())
  end)

  it("sums or maxes unknown types as max", function()
    queue:Add({ type = "nope", value = 1 })
    queue:Add({ type = "nope", value = 3 })
    assert.are.equal(3, queue.facts[1].value)
  end)

  it("does not flush a queue that is still locked, unless forced", function()
    locked = true
    det:Publish({ { type = "level", value = 10 } })
    assert.are.equal(0, queue:Flush(false))
    assert.are.equal(1, queue:Pending())
    assert.are.equal(1, queue:Flush(true))
    assert.are.equal(0, queue:Pending())
    assert.is_not_nil(env.h.earned("t_level"))
    assert.are.equal(0, queue:Flush(true))
  end)

  it("contains a fact that raises and still feeds the others", function()
    locked = true
    det:Publish({ { type = "level", value = 10 }, { type = "money", value = 1 } })
    local feed = env.app.engine.Feed
    env.app.engine.Feed = function(self, fact)
      if fact.type == "level" then
        error("boom")
      end
      return feed(self, fact)
    end
    assert.has_no.errors(function()
      queue:Flush(true)
    end)
    assert.is_truthy(queue.lastError:find("boom", 1, true))
    assert.are.equal(0, queue:Pending())
  end)

  describe("events", function()
    local function fire(event)
      queue.frame.scripts.OnEvent(queue.frame, event)
    end

    it("registers ENCOUNTER_END and PLAYER_REGEN_ENABLED once", function()
      local registration = queue:Start()
      assert.are.same({ "ENCOUNTER_END", "PLAYER_REGEN_ENABLED" }, registration.registered)
      assert.are.equal(registration, queue:Start())
    end)

    it("reports no registration when the client cannot make a frame", function()
      local real = _G.CreateFrame
      _G.CreateFrame = nil
      local registration = queue:Start()
      _G.CreateFrame = real
      assert.are.same({}, registration.registered)
      assert.is_nil(queue.frame)
    end)

    it("flushes on ENCOUNTER_END even if the client still reports the encounter", function()
      queue:Start()
      inEncounter = true
      det:Publish({ { type = "level", value = 10 } })
      fire("ENCOUNTER_END")
      assert.is_not_nil(env.h.earned("t_level"))
    end)

    it("waits one throttle delay after ENCOUNTER_END when the client has a timer", function()
      env.useTimer()
      queue:Start()
      inEncounter = true
      det:Publish({ { type = "level", value = 10 } })
      fire("ENCOUNTER_END")
      assert.is_nil(env.h.earned("t_level"))
      assert.are.equal(env.ns.Detector.THROTTLE_SECONDS, env.timers[1].seconds)
      -- A fact produced by the same event is still caught by the flush.
      det:Publish({ { type = "money", value = 5 } })
      env.flush()
      assert.is_not_nil(env.h.earned("t_level"))
      assert.are.equal(0, queue:Pending())
    end)

    it("flushes on PLAYER_REGEN_ENABLED only when the lockdown is over", function()
      queue:Start()
      inEncounter = true
      det:Publish({ { type = "level", value = 10 } })
      fire("PLAYER_REGEN_ENABLED")
      assert.is_nil(env.h.earned("t_level"))
      inEncounter = false
      fire("PLAYER_REGEN_ENABLED")
      assert.is_not_nil(env.h.earned("t_level"))
    end)
  end)

  it("is started by App:Start after the detectors", function()
    env.ns.UI = nil
    env.app:Start()
    assert.is_not_nil(env.app.queue.registration)
    assert.is_nil(env.app.errors[1])
  end)

  it("publishes straight to the engine when the app has no queue", function()
    env.app.queue = nil
    locked = true
    det:Publish({ { type = "level", value = 10 } })
    assert.is_not_nil(env.h.earned("t_level"))
  end)
end)

local Env = dofile("tests/support/detector_env.lua")

describe("Encounters detector", function()
  local env, det

  before_each(function()
    env = Env.Build()
    env.ns.db = nil
    _G.IsInInstance = function()
      return true, "raid"
    end
    det = env.add("Encounters")
    det:Start()
  end)

  after_each(function()
    env.ns.db = nil
    env.close()
  end)

  it("registers ENCOUNTER_END and has no retro answer", function()
    assert.are.same({ "ENCOUNTER_END" }, det.registration.registered)
    assert.are.same({}, det:Facts())
  end)

  it("feeds an encounter fact for a kill and bumps the boss statistics", function()
    env.fire(det, "ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)
    assert.are.equal(1, env.h.store:Progress("Player-1")["encounter:1084"])
    assert.is_false(env.h.earned("t_encounter").retro)
    assert.are.equal(1, env.app.stats:Get("bosses_killed"))
    assert.are.equal(1, env.app.stats:Get("raid_bosses"))
    assert.are.equal(0, env.app.stats:Get("dungeon_bosses"))
  end)

  it("counts every kill of the same boss", function()
    env.fire(det, "ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)
    env.fire(det, "ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)
    assert.are.equal(2, env.h.store:Progress("Player-1")["encounter:1084"])
  end)

  it("counts a dungeon boss as such", function()
    _G.IsInInstance = function()
      return true, "party"
    end
    env.fire(det, "ENCOUNTER_END", 5, "Boss", 1, 5, 1)
    assert.are.equal(1, env.app.stats:Get("dungeon_bosses"))
    assert.are.equal(0, env.app.stats:Get("raid_bosses"))
  end)

  it("ignores wipes, and unreadable arguments", function()
    env.fire(det, "ENCOUNTER_END", 1084, "Onyxia", 9, 40, 0)
    env.fire(det, "ENCOUNTER_END", nil, "Onyxia", 9, 40, 1)
    env.fire(det, "ENCOUNTER_END", "x", "Onyxia", 9, 40, 1)
    env.fire(det, "ENCOUNTER_END", 1084, "Onyxia", 9, 40)
    assert.is_nil(env.h.store:Progress("Player-1")["encounter:1084"])
    assert.is_nil(det.log)
    _G.issecretvalue = function()
      return true
    end
    env.fire(det, "ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)
    assert.is_nil(env.h.store:Progress("Player-1")["encounter:1084"])
  end)

  it("works when the client cannot tell the instance type", function()
    _G.IsInInstance = nil
    env.fire(det, "ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)
    assert.are.equal(1, env.app.stats:Get("bosses_killed"))
    assert.are.equal(0, env.app.stats:Get("raid_bosses"))
  end)

  it("logs the difficulty in memory, bounded", function()
    for index = 1, env.ns.Detectors.Encounters.LOG_SIZE + 5 do
      env.fire(det, "ENCOUNTER_END", index, "Boss", 14, 10, 1)
    end
    assert.are.equal(env.ns.Detectors.Encounters.LOG_SIZE, #det.log)
    assert.are.same({ encounterID = 25, difficultyID = 14, instanceType = "raid" }, det.log[#det.log])
    assert.are.equal(6, det.log[1].encounterID)
  end)

  it("also logs into the saved debug table when there is a database", function()
    env.ns.db = {}
    env.fire(det, "ENCOUNTER_END", 7, "Boss", 14, 10, 1)
    assert.are.equal(14, env.ns.db.debug.encounters[1].difficultyID)
    env.ns.db = { debug = { encounters = "old" } }
    env.fire(det, "ENCOUNTER_END", 8, "Boss", 14, 10, 1)
    assert.are.equal(8, env.ns.db.debug.encounters[1].encounterID)
  end)

  it("waits in the queue during the encounter and feeds the kill when it ends", function()
    local inEncounter = true
    _G.IsEncounterInProgress = function()
      return inEncounter
    end
    env.app.queue:Start()
    env.fire(det, "ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)
    assert.is_nil(env.h.store:Progress("Player-1")["encounter:1084"])
    assert.are.equal(1, env.app.queue:Pending())
    env.app.queue.frame.scripts.OnEvent(env.app.queue.frame, "ENCOUNTER_END")
    assert.are.equal(1, env.h.store:Progress("Player-1")["encounter:1084"])
    assert.are.equal(1, env.app.stats:Get("bosses_killed"))
  end)
end)

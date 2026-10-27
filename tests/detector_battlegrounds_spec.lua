local Env = dofile("tests/support/detector_env.lua")

describe("Battlegrounds detector", function()
  local env, det, instance, winner, faction

  local function install()
    _G.GetInstanceInfo = function()
      return instance.name, instance.kind, 0, "", 0, 0, false, instance.id
    end
    _G.GetBattlefieldWinner = function()
      return winner
    end
    _G.UnitFactionGroup = function()
      return faction, faction
    end
  end

  local function enter(id, name)
    instance = { name = name or "Warsong Gulch", kind = "pvp", id = id or 489 }
  end

  local function leave()
    instance = { name = "Stormwind City", kind = "none", id = 0 }
  end

  local function progress(key)
    return env.h.store:Progress("Player-1")[key]
  end

  before_each(function()
    env = Env.Build()
    winner, faction = nil, "Alliance"
    leave()
    install()
    det = env.add("Battlegrounds")
  end)

  after_each(function()
    env.close()
  end)

  it("registers its events and has no retro answer", function()
    det:Start()
    assert.are.same(
      { "UPDATE_BATTLEFIELD_STATUS", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" },
      det.registration.registered
    )
    assert.are.same({}, det:Facts())
  end)

  it("counts a game played once, however many events arrive", function()
    det:Start()
    enter(489)
    env.fire(det, "PLAYER_ENTERING_WORLD")
    env.fire(det, "UPDATE_BATTLEFIELD_STATUS", 1)
    env.fire(det, "ZONE_CHANGED_NEW_AREA")
    assert.are.equal(1, progress("bg_played:489"))
    assert.are.equal(1, env.app.stats:Get("bg_played"))
    assert.are.equal(1, env.app.stats:Get("bg_played_489"))
  end)

  it("counts a win when the winner is the player's faction", function()
    det:Start()
    enter(489)
    env.fire(det, "PLAYER_ENTERING_WORLD")
    winner = 1
    env.fire(det, "UPDATE_BATTLEFIELD_STATUS", 1)
    env.fire(det, "UPDATE_BATTLEFIELD_STATUS", 1)
    assert.are.equal(1, progress("bg_win:489"))
    assert.are.equal(1, env.app.stats:Get("bg_won"))
    assert.are.equal(1, env.app.stats:Get("bg_won_489"))
  end)

  it("does not count a loss, and resolves the game only once", function()
    det:Start()
    enter(529, "Arathi Basin")
    env.fire(det, "PLAYER_ENTERING_WORLD")
    winner = 0
    env.fire(det, "UPDATE_BATTLEFIELD_STATUS", 1)
    assert.is_nil(progress("bg_win:529"))
    faction = "Horde"
    env.fire(det, "UPDATE_BATTLEFIELD_STATUS", 1)
    assert.is_nil(progress("bg_win:529"))
  end)

  it("counts a Horde win as winner 0", function()
    faction = "Horde"
    det:Start()
    enter(30, "Alterac Valley")
    env.fire(det, "PLAYER_ENTERING_WORLD")
    winner = 0
    env.fire(det, "UPDATE_BATTLEFIELD_STATUS", 1)
    assert.are.equal(1, progress("bg_win:30"))
  end)

  it("does not guess a win without a known faction", function()
    det:Start()
    enter(489)
    env.fire(det, "PLAYER_ENTERING_WORLD")
    _G.UnitFactionGroup = nil
    winner = 1
    env.fire(det, "UPDATE_BATTLEFIELD_STATUS", 1)
    assert.is_nil(progress("bg_win:489"))
  end)

  it("ignores a stale winner on the event that begins the game", function()
    det:Start()
    winner = 1
    enter(489)
    env.fire(det, "PLAYER_ENTERING_WORLD")
    assert.are.equal(1, progress("bg_played:489"))
    assert.is_nil(progress("bg_win:489"))
  end)

  it("counts two games one after the other, and a direct jump to another battleground", function()
    det:Start()
    enter(489)
    env.fire(det, "PLAYER_ENTERING_WORLD")
    leave()
    env.fire(det, "PLAYER_ENTERING_WORLD")
    enter(489)
    env.fire(det, "PLAYER_ENTERING_WORLD")
    assert.are.equal(2, progress("bg_played:489"))
    enter(529)
    env.fire(det, "PLAYER_ENTERING_WORLD")
    assert.are.equal(1, progress("bg_played:529"))
    assert.are.equal(3, env.app.stats:Get("bg_played"))
  end)

  it("ignores arenas, the open world and an unreadable instance", function()
    det:Start()
    instance = { name = "Nagrand Arena", kind = "arena", id = 559 }
    env.fire(det, "PLAYER_ENTERING_WORLD")
    leave()
    env.fire(det, "UPDATE_BATTLEFIELD_STATUS", 1)
    instance = { name = "x", kind = "pvp" }
    env.fire(det, "PLAYER_ENTERING_WORLD")
    _G.GetInstanceInfo = nil
    env.fire(det, "PLAYER_ENTERING_WORLD")
    assert.are.equal(0, env.app.stats:Get("bg_played"))
  end)

  it("adopts a battleground it finds at start without counting it again", function()
    enter(489)
    det:Start()
    env.fire(det, "ZONE_CHANGED_NEW_AREA")
    assert.is_nil(progress("bg_played:489"))
    winner = 1
    env.fire(det, "UPDATE_BATTLEFIELD_STATUS", 1)
    assert.are.equal(1, progress("bg_win:489"))
  end)

  it("adopts a finished battleground as already resolved", function()
    enter(489)
    winner = 1
    det:Start()
    env.fire(det, "UPDATE_BATTLEFIELD_STATUS", 1)
    assert.is_nil(progress("bg_win:489"))
  end)
end)

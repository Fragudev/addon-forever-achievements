local Env = dofile("tests/support/detector_env.lua")

describe("Snapshot detector", function()
  local env, det

  before_each(function()
    env = Env.Build()
    _G.GetUnitName = function()
      return "Mary Ann"
    end
    _G.UnitClass = function()
      return "Warrior", "WARRIOR", 1
    end
    _G.UnitRace = function()
      return "Human", "Human", 1
    end
    _G.UnitFactionGroup = function()
      return "Alliance", "Alliance"
    end
    _G.UnitLevel = function()
      return 60
    end
    _G.GetMoney = function()
      return 4321
    end
    det = env.add("Snapshot")
  end)

  after_each(function()
    env.close()
  end)

  it("reads the character info with the display name", function()
    assert.are.same(
      { name = "Mary Ann", class = "WARRIOR", race = "Human", faction = "Alliance", level = 60 },
      det:Info()
    )
  end)

  it("leaves out what the client cannot give", function()
    for _, name in ipairs({ "GetUnitName", "UnitClass", "UnitRace", "UnitFactionGroup", "UnitLevel" }) do
      _G[name] = nil
    end
    assert.are.same({}, det:Info())
  end)

  it("builds the snapshot from the fields of the other detectors", function()
    env.add("Money")
    env.add("Played")
    local broken = env.add("Level")
    broken.SnapshotFields = function()
      error("boom")
    end
    env.app.detectors.Played.total = 900
    assert.are.same({ money = 4321, played = 900 }, det:Build())
  end)

  it("records the info and the whole snapshot on Refresh", function()
    env.add("Money")
    det:Refresh()
    local char = env.h.store:FindCharacter("Player-1")
    assert.are.equal("Mary Ann", char.name)
    assert.are.equal("WARRIOR", char.class)
    assert.are.equal(60, char.level)
    assert.are.equal(4321, char.snapshot.money)
  end)

  it("lets an override win over the info read from the client", function()
    det:Update({}, { level = 61 })
    assert.are.equal(61, env.h.store:FindCharacter("Player-1").level)
  end)

  it("records nothing without a GUID", function()
    env.h.guid = nil
    assert.are.equal(0, det:Update({ money = 1 }))
    assert.are.equal(0, env.h.store:FindCharacter("Player-1").snapshot.money)
  end)

  it("re-evaluates the account achievements when it records", function()
    env.h.store:GetCharacter("Player-2", { name = "Other", class = "MAGE", level = 60 })
    det:Update({ money = 4999 })
    assert.is_nil(env.h.store:AccountEarned().t_acc_money)
    assert.are.equal(1, det:Update({ money = 5000 }))
    assert.is_not_nil(env.h.store:AccountEarned().t_acc_money)
  end)

  describe("Queue", function()
    it("merges the fields and records them once after the delay", function()
      env.useTimer()
      det:Queue({ money = 1 })
      det:Queue({ money = 2, played = 3 })
      assert.are.equal(1, #env.timers)
      assert.are.equal(0, env.h.store:Snapshot("Player-1").money)
      env.flush()
      assert.are.equal(2, env.h.store:Snapshot("Player-1").money)
      assert.are.equal(3, env.h.store:Snapshot("Player-1").played)
      assert.are.equal(0, det:Flush())
    end)

    it("records at once without a client timer", function()
      det:Queue({ money = 7 })
      assert.are.equal(7, env.h.store:Snapshot("Player-1").money)
    end)

    it("contains an error when the delayed record fails", function()
      env.useTimer()
      det.Update = function()
        error("boom")
      end
      det:Queue({ money = 7 })
      assert.has_no.errors(function()
        env.flush()
      end)
      assert.is_truthy(det.lastError:find("boom", 1, true))
    end)
  end)

  describe("PLAYER_LOGOUT", function()
    it("registers the event and records the whole snapshot, dropping what was queued", function()
      env.add("Money")
      env.useTimer()
      det:Start()
      det:Queue({ money = 1 })
      env.fire(det, "PLAYER_LOGOUT")
      assert.are.equal(4321, env.h.store:Snapshot("Player-1").money)
      env.flush()
      assert.are.equal(4321, env.h.store:Snapshot("Player-1").money)
    end)

    it("ignores other events", function()
      assert.is_nil(det:Handle("SOMETHING_ELSE"))
    end)
  end)
end)

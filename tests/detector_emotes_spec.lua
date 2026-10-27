local Env = dofile("tests/support/detector_env.lua")

describe("Emotes detector", function()
  local env, det, target, clock

  local function emote(token)
    _G.__hooks.DoEmote(token, "target")
  end

  before_each(function()
    env = Env.Build()
    _G.__hooks = nil
    _G.DoEmote = function() end
    target = "Creature-0-3-0-0-2442-0000ABCD12"
    _G.UnitGUID = function(unit)
      if unit == "target" then
        return target
      end
      return "Player-1"
    end
    det = env.add("Emotes")
    det:Start()
  end)

  after_each(function()
    _G.__hooks = nil
    env.close()
  end)

  local function progress(key)
    return env.h.store:Progress("Player-1")[key]
  end

  it("hooks DoEmote and has no retro answer", function()
    assert.is_true(det.hooks.DoEmote)
    assert.is_false(det.hooks.PerformEmote)
    assert.are.same({}, det:Facts())
  end)

  it("also hooks C_ChatInfo.PerformEmote when the client has it", function()
    _G.__hooks = nil
    _G.C_ChatInfo = { PerformEmote = function() end }
    local other = env.add("Emotes")
    other:OnStart()
    assert.is_true(other.hooks.PerformEmote)
    _G.__hooks.PerformEmote("love")
    assert.are.equal(1, progress("emote_target:LOVE:2442"))
  end)

  it("feeds LOVE:<npc id> for an emote at a creature and counts it", function()
    emote("love")
    assert.are.equal(1, progress("emote_target:LOVE:2442"))
    assert.are.equal(1, env.app.stats:Get("emotes_used"))
  end)

  it("adds up the emotes at the same creature and grants the achievement", function()
    env.ns.Catalog.Register({
      {
        id = "t_love",
        category = "general.misc",
        points = 5,
        scope = "character",
        icon = 1,
        retroactive = false,
        ref = {},
        criteria = { { type = "emote_target", key = "LOVE:2442", value = 2 } },
      },
    })
    emote("LOVE")
    assert.is_nil(env.h.earned("t_love"))
    emote("LOVE")
    assert.is_false(env.h.earned("t_love").retro)
  end)

  it("counts an emote without a creature target only in the statistic", function()
    target = nil
    emote("DANCE")
    target = "Player-1-0000ABCD"
    emote("DANCE")
    target = "Pet-0-3-0-0-2442-0000ABCD12"
    emote("DANCE")
    target = 5
    emote("DANCE")
    assert.are.equal(4, env.app.stats:Get("emotes_used"))
    assert.is_nil(progress("emote_target:DANCE:2442"))
  end)

  it("parses the npc id of a creature GUID only", function()
    local Emotes = env.ns.Detectors.Emotes
    assert.are.equal(2442, Emotes.NpcId("Creature-0-3-0-0-2442-0000ABCD12"))
    assert.are.equal(61, Emotes.NpcId("Creature-0-1465-0-1107-61-0000ABCD12"))
    assert.is_nil(Emotes.NpcId("Vehicle-0-3-0-0-2442-0000ABCD12"))
    assert.is_nil(Emotes.NpcId("Creature-0-3-0-0-x-0000ABCD12"))
    assert.is_nil(Emotes.NpcId(nil))
  end)

  it("ignores unreadable tokens", function()
    emote(nil)
    emote(5)
    emote("")
    _G.issecretvalue = function()
      return true
    end
    emote("LOVE")
    assert.are.equal(0, env.app.stats:Get("emotes_used"))
  end)

  describe("repeated hook calls", function()
    before_each(function()
      clock = 100
      _G.GetTime = function()
        return clock
      end
    end)

    it("count once when both hooks fire for the same emote", function()
      emote("LOVE")
      clock = clock + 0.01
      emote("LOVE")
      assert.are.equal(1, progress("emote_target:LOVE:2442"))
    end)

    it("count again later or for another emote", function()
      emote("LOVE")
      clock = clock + 0.01
      emote("DANCE")
      clock = clock + 5
      emote("DANCE")
      assert.are.equal(1, progress("emote_target:LOVE:2442"))
      assert.are.equal(2, progress("emote_target:DANCE:2442"))
    end)

    it("are not merged without a clock", function()
      _G.GetTime = nil
      emote("LOVE")
      emote("LOVE")
      assert.are.equal(2, progress("emote_target:LOVE:2442"))
    end)
  end)

  it("contains an error", function()
    env.app.stats.Increment = function()
      error("boom")
    end
    assert.has_no.errors(function()
      emote("LOVE")
    end)
    assert.is_truthy(det.lastError:find("boom", 1, true))
  end)

  it("waits for the end of an encounter", function()
    _G.IsEncounterInProgress = function()
      return true
    end
    emote("LOVE")
    assert.is_nil(progress("emote_target:LOVE:2442"))
    assert.are.equal(1, env.app.queue:Pending())
  end)
end)

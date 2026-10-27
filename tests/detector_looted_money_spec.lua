local Env = dofile("tests/support/detector_env.lua")

describe("LootedMoney detector", function()
  local env, det

  local function progress()
    return env.h.store:Progress("Player-1").money_looted
  end

  before_each(function()
    env = Env.Build()
    _G.GOLD_AMOUNT = "%d Gold"
    _G.SILVER_AMOUNT = "%d Silver"
    _G.COPPER_AMOUNT = "%d Copper"
    _G.YOU_LOOT_MONEY = "You loot %s."
    _G.LOOT_MONEY_SPLIT = "Your share of the loot is %s."
    det = env.add("LootedMoney")
    det:Start()
  end)

  after_each(function()
    env.close()
  end)

  it("registers CHAT_MSG_MONEY and has no retro answer", function()
    assert.are.same({ "CHAT_MSG_MONEY" }, det.registration.registered)
    assert.are.same({}, det:Facts())
  end)

  it("parses gold, silver and copper of the player's loot", function()
    env.fire(det, "CHAT_MSG_MONEY", "You loot 5 Gold, 4 Silver, 3 Copper.")
    assert.are.equal(50403, progress())
    assert.are.equal(50403, env.app.stats:Get("gold_looted"))
  end)

  it("adds each loot message", function()
    env.fire(det, "CHAT_MSG_MONEY", "You loot 12 Copper.")
    env.fire(det, "CHAT_MSG_MONEY", "You loot 3 Silver.")
    env.fire(det, "CHAT_MSG_MONEY", "You loot 2 Gold.")
    assert.are.equal(20312, progress())
  end)

  it("parses a share of a split loot", function()
    env.fire(det, "CHAT_MSG_MONEY", "Your share of the loot is 1 Silver, 20 Copper.")
    assert.are.equal(120, progress())
  end)

  it("reads thousands separators", function()
    env.fire(det, "CHAT_MSG_MONEY", "You loot 1,234 Gold.")
    assert.are.equal(12340000, progress())
  end)

  it("works with another locale's words and order", function()
    _G.GOLD_AMOUNT = "%d Oro"
    _G.SILVER_AMOUNT = "%d Plata"
    _G.COPPER_AMOUNT = "%d Cobre"
    _G.YOU_LOOT_MONEY = "Saqueas %s."
    det.patterns = nil
    env.fire(det, "CHAT_MSG_MONEY", "Saqueas 1 Oro, 2 Plata, 3 Cobre.")
    assert.are.equal(10203, progress())
  end)

  it("ignores other players' loot, other text and zero", function()
    env.fire(det, "CHAT_MSG_MONEY", "Thrall loots 5 Gold.")
    env.fire(det, "CHAT_MSG_MONEY", "You loot nothing useful.")
    env.fire(det, "CHAT_MSG_MONEY", "You loot 0 Copper.")
    env.fire(det, "CHAT_MSG_MONEY", "")
    assert.is_nil(progress())
  end)

  it("ignores text that is not a readable string", function()
    env.fire(det, "CHAT_MSG_MONEY", nil)
    env.fire(det, "CHAT_MSG_MONEY", 5)
    _G.issecretvalue = function()
      return true
    end
    env.fire(det, "CHAT_MSG_MONEY", "You loot 5 Gold.")
    assert.is_nil(progress())
  end)

  it("publishes nothing when the client lacks the localized formats", function()
    _G.COPPER_AMOUNT = nil
    det.patterns = nil
    env.fire(det, "CHAT_MSG_MONEY", "You loot 5 Copper.")
    assert.is_nil(progress())
    _G.COPPER_AMOUNT = "%d Copper"
    _G.YOU_LOOT_MONEY, _G.LOOT_MONEY_SPLIT = nil, nil
    env.fire(det, "CHAT_MSG_MONEY", "You loot 5 Copper.")
    assert.is_nil(progress())
  end)

  it("recovers once the globals exist", function()
    det.patterns = nil
    _G.COPPER_AMOUNT = nil
    env.fire(det, "CHAT_MSG_MONEY", "You loot 5 Copper.")
    _G.COPPER_AMOUNT = "%d Copper"
    env.fire(det, "CHAT_MSG_MONEY", "You loot 5 Copper.")
    assert.are.equal(5, progress())
  end)

  it("keeps a built pattern set", function()
    env.fire(det, "CHAT_MSG_MONEY", "You loot 5 Copper.")
    local patterns = det.patterns
    env.fire(det, "CHAT_MSG_MONEY", "You loot 5 Copper.")
    assert.are.equal(patterns, det.patterns)
  end)

  describe("ToPattern", function()
    local ToPattern

    before_each(function()
      ToPattern = env.ns.Detectors.LootedMoney.ToPattern
    end)

    it("escapes the format and captures the arguments", function()
      assert.are.equal("^You loot (.+)%.$", ToPattern("You loot %s."))
      assert.are.equal("^([%d%.,]+) Gold %(x%)$", ToPattern("%d Gold (x)"))
    end)

    it("refuses formats it cannot follow", function()
      assert.is_nil(ToPattern(nil))
      assert.is_nil(ToPattern("no captures"))
      assert.is_nil(ToPattern("%2$s loots %1$s"))
    end)
  end)
end)

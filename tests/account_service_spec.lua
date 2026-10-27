local Harness = dofile("tests/support/harness.lua")

describe("AccountService", function()
  local h

  before_each(function()
    h = Harness.Build()
    h.store:GetCharacter("Player-2", { name = "Warrior", class = "WARRIOR", faction = "Alliance", level = 10 })
    h.store:GetCharacter("Player-3", { name = "Priest", class = "PRIEST", faction = "Horde", level = 60 })
  end)

  local function value(criterionType, key)
    return h.account:Value({ type = criterionType, key = key, value = 1 })
  end

  it("counts the characters at or above a level", function()
    assert.are.equal(3, value("account_level_count"))
    assert.are.equal(2, value("account_level_count", 10))
    assert.are.equal(1, value("account_level_count", 60))
  end)

  it("treats a character without level as level 0", function()
    h.store:GetCharacter("Player-4", {})
    assert.are.equal(3, value("account_level_count", 1))
  end)

  it("counts distinct classes", function()
    assert.are.equal(2, value("account_class_set"))
    h.store:GetCharacter("Player-4", { class = "MAGE" })
    h.store:GetCharacter("Player-5", {})
    assert.are.equal(3, value("account_class_set"))
  end)

  it("sums the snapshot money", function()
    h.store:Snapshot("Player-1").money = 100
    h.store:Snapshot("Player-3").money = 250
    h.store:FindCharacter("Player-2").snapshot = nil
    assert.are.equal(350, value("account_money"))
  end)

  it("sums the points of the earned character achievements, feats excluded", function()
    h.store:Earned("Player-1").t_level = { at = 1 }
    h.store:Earned("Player-1").t_feat = { at = 1 }
    h.store:Earned("Player-3").t_meta = { at = 1 }
    h.store:Earned("Player-3").ghost = { at = 1 }
    h.store:Earned("Player-3").t_acc_money = { at = 1 }
    assert.are.equal(5, h.account:CharacterPoints("Player-1"))
    assert.are.equal(10, h.account:CharacterPoints("Player-3"))
    assert.are.equal(0, h.account:CharacterPoints("Player-2"))
    assert.are.equal(0, h.account:CharacterPoints("unknown"))
    assert.are.equal(15, h.account:TotalPoints())
    assert.are.equal(15, value("account_points"))
  end)

  it("awards the account achievements on Refresh", function()
    assert.are.equal(1, h.account:Refresh())
    assert.is_not_nil(h.store:AccountEarned().t_acc_levels)
    assert.are.equal(0, h.account:Refresh())
  end)

  it("Record stores the info and snapshot and awards what is now met", function()
    local awarded = h.account:Record("Player-1", { level = 60, class = "WARRIOR" }, { money = 6000, played = 10 })
    assert.are.equal(2, awarded)
    assert.are.equal(60, h.store:FindCharacter("Player-1").level)
    assert.are.equal(10, h.store:Snapshot("Player-1").played)
    assert.is_not_nil(h.store:AccountEarned().t_acc_money)
    assert.is_not_nil(h.store:AccountEarned().t_acc_levels)
    assert.are.equal("Player-1", h.store:AccountEarned().t_acc_money.by)
  end)

  it("Record works without a snapshot and ignores an invalid GUID", function()
    assert.are.equal(1, h.account:Record("Player-1", { level = 20 }))
    assert.are.equal(0, h.account:Record(nil, {}))
  end)

  it("is not affected by forgotten characters", function()
    h.store:Forget("Player-3")
    assert.are.equal(2, value("account_level_count"))
  end)
end)

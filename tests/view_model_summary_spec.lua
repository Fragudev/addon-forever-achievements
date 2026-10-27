local UiHarness = dofile("tests/support/ui_harness.lua")

describe("ViewModelSummary", function()
  local h, Summary

  before_each(function()
    h = UiHarness.Build()
    h.ns.Locale.Use("enUS")
    Summary = h.ns.ViewModelSummary
    h.store:GetCharacter("Player-2", { name = "Warlock", class = "WARLOCK", faction = "Horde", level = 20 })
  end)

  it("is empty and zero-safe for a fresh character", function()
    local data = Summary.Build(h.ctx("character"))
    assert.are.equal(0, data.points)
    assert.are.same({}, data.recent)
    assert.are.equal(0, data.overall.earned)
    assert.is_true(data.overall.total > 0)
    assert.are.equal(0, data.overall.fraction)
    for _, category in ipairs(data.categories) do
      assert.is_true(category.total > 0)
      assert.are.equal(0, category.fraction)
    end
  end)

  it("is zero-safe when nothing at all can be shown", function()
    h.ns.Catalog.Reset()
    local data = Summary.Build(h.ctx("character"))
    assert.are.equal(0, data.overall.total)
    assert.are.equal(0, data.overall.fraction)
    assert.are.equal("0/0", data.overall.text)
    assert.are.same({}, data.categories)
  end)

  it("lists the five latest earned achievements, newest first", function()
    local order = { "t_level", "t_money", "t_played", "t_quest_count", "t_death", "t_skill_count", "t_pet_count" }
    for index, id in ipairs(order) do
      h.give("Player-1", id, 100 + index)
    end
    local data = Summary.Build(h.ctx("character"))
    assert.are.equal(5, #data.recent)
    assert.are.equal("t_pet_count", data.recent[1].id)
    assert.are.equal("t_played", data.recent[5].id)
  end)

  it("breaks ties by id and keeps retro grants labelled", function()
    h.give("Player-1", "t_money", 50, true)
    h.give("Player-1", "t_level", 50)
    local recent = Summary.Build(h.ctx("character")).recent
    assert.are.same({ "t_level", "t_money" }, { recent[1].id, recent[2].id })
    assert.are.equal("Earned before the addon", recent[2].dateText)
  end)

  it("counts per top-level category with a fraction and the points", function()
    h.give("Player-1", "t_level", 1)
    h.give("Player-1", "t_feat", 1)
    local data = Summary.Build(h.ctx("character"))
    local byId = {}
    for _, category in ipairs(data.categories) do
      byId[category.id] = category
    end
    assert.are.equal(1, byId.general.earned)
    assert.are.equal(1, byId.feats.earned)
    assert.are.equal(1, byId.feats.total)
    assert.are.equal(1, byId.feats.fraction)
    assert.are.equal("1/1", byId.feats.text)
    assert.are.equal(2, data.overall.earned)
    assert.are.equal(5, data.points)
  end)

  it("includes other characters and account achievements in the account view", function()
    h.give("Player-2", "t_level", 10)
    h.store:AccountEarned().t_acc_levels = { at = 20, retro = false, by = "Player-2" }
    local data = Summary.Build(h.ctx("account"))
    assert.are.same({ "t_acc_levels", "t_level" }, { data.recent[1].id, data.recent[2].id })
    assert.are.equal("Earned by Warlock on " .. h.ns.ViewModel.FormatDate(10), data.recent[2].dateText)
    assert.are.equal(10, data.points)
  end)
end)

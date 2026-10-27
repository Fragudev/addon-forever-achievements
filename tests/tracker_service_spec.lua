local Harness = dofile("tests/support/harness.lua")

describe("TrackerService", function()
  local h, tracker

  before_each(function()
    h = Harness.Build()
    tracker = h.ns.TrackerService.New({ settings = h.ns.Settings.New(h.store), catalog = h.ns.Catalog })
  end)

  it("tracks and lists in order, persisting in the settings", function()
    assert.is_true(tracker:Track("t_level"))
    assert.is_true(tracker:Track("t_money"))
    assert.are.same({ "t_level", "t_money" }, tracker:List())
    assert.are.same({ "t_level", "t_money" }, h.store:Settings().tracked)
    assert.is_true(tracker:IsTracked("t_money"))
    assert.is_false(tracker:IsTracked("t_played"))
  end)

  it("returns a copy from List", function()
    tracker:Track("t_level")
    tracker:List()[1] = "changed"
    assert.are.same({ "t_level" }, tracker:List())
  end)

  it("rejects an unknown achievement and a repeated one", function()
    local ok, reason = tracker:Track("ghost")
    assert.is_false(ok)
    assert.are.equal("unknown", reason)
    tracker:Track("t_level")
    ok, reason = tracker:Track("t_level")
    assert.is_false(ok)
    assert.are.equal("already", reason)
  end)

  it("caps the tracker at 10", function()
    local ids = {}
    for _, ach in ipairs(h.ns.Catalog.All()) do
      ids[#ids + 1] = ach.id
    end
    for index = 1, 10 do
      assert.is_true(tracker:Track(ids[index]))
    end
    local ok, reason = tracker:Track(ids[11])
    assert.is_false(ok)
    assert.are.equal("full", reason)
    assert.are.equal(10, #tracker:List())
    assert.are.equal(10, h.ns.TrackerService.MAX)
  end)

  it("frees a slot when untracking", function()
    for _, id in ipairs({ "t_level", "t_money", "t_played", "t_death", "t_pet_count" }) do
      tracker:Track(id)
    end
    assert.is_true(tracker:Untrack("t_played"))
    assert.is_false(tracker:Untrack("t_played"))
    assert.are.same({ "t_level", "t_money", "t_death", "t_pet_count" }, tracker:List())
  end)

  it("toggles", function()
    local ok, state = tracker:Toggle("t_level")
    assert.is_true(ok)
    assert.is_true(state)
    ok, state = tracker:Toggle("t_level")
    assert.is_true(ok)
    assert.is_false(state)
    local failed, reason = tracker:Toggle("ghost")
    assert.is_false(failed)
    assert.are.equal("unknown", reason)
  end)
end)

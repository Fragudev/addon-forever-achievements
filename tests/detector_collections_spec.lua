local Env = dofile("tests/support/detector_env.lua")

describe("Collections detector", function()
  local env, det, mounts, pets, toys

  before_each(function()
    env = Env.Build()
    mounts = { [10] = true, [11] = false, [12] = true }
    pets = { 90, 4 }
    toys = 3
    _G.C_MountJournal = {
      GetMountIDs = function()
        return { 10, 11, 12 }
      end,
      GetMountInfoByID = function(id)
        return "m", 1, 1, false, true, 0, false, false, nil, false, mounts[id], id
      end,
    }
    _G.C_PetJournal = {
      GetNumPets = function()
        return pets[1], pets[2]
      end,
    }
    _G.C_ToyBox = {
      GetNumLearnedDisplayedToys = function()
        return toys
      end,
    }
    det = env.add("Collections")
  end)

  after_each(function()
    env.close()
  end)

  it("gives the three counts to the retro scan", function()
    assert.are.same({
      { type = "mount_count", value = 2 },
      { type = "pet_count", value = 4 },
      { type = "toy_count", value = 3 },
    }, det:Facts())
    det:Start()
    env.app.retro:Run()
    assert.is_true(env.h.earned("t_mount_count").retro)
    assert.is_true(env.h.earned("t_pet_count").retro)
    assert.is_true(env.h.earned("t_toy_count").retro)
  end)

  it("skips a journal that does not exist", function()
    _G.C_MountJournal = nil
    _G.C_ToyBox = nil
    assert.are.same({ { type = "pet_count", value = 4 } }, det:Facts())
    _G.C_PetJournal = nil
    assert.are.same({}, det:Facts())
  end)

  it("skips a journal that raises", function()
    _G.C_PetJournal = {
      GetNumPets = function()
        error("boom")
      end,
    }
    _G.C_ToyBox = {
      GetNumLearnedDisplayedToys = function()
        error("boom")
      end,
    }
    assert.are.same({ { type = "mount_count", value = 2 } }, det:Facts())
  end)

  it("re-reads only the journal of the event, coalesced", function()
    env.useTimer()
    det:Start()
    env.fire(det, "NEW_MOUNT_ADDED", 99)
    env.fire(det, "NEW_MOUNT_ADDED", 100)
    env.fire(det, "NEW_PET_ADDED")
    env.fire(det, "NEW_TOY_ADDED")
    assert.are.equal(3, #env.timers)
    env.flush()
    local progress = env.h.store:Progress("Player-1")
    assert.are.equal(2, progress.mount_count)
    assert.are.equal(4, progress.pet_count)
    assert.are.equal(3, progress.toy_count)
    assert.is_false(env.h.earned("t_mount_count").retro)
  end)

  it("ignores an event it does not know", function()
    assert.is_nil(det:Handle("SOMETHING_ELSE"))
    assert.is_nil(env.h.store:Progress("Player-1").mount_count)
  end)
end)

local Env = dofile("tests/support/detector_env.lua")

describe("Items detector", function()
  local env, det, counts, equipped

  local function progress(key)
    return env.h.store:Progress("Player-1")[key]
  end

  before_each(function()
    env = Env.Build()
    counts = { [6948] = 1 }
    equipped = {}
    _G.GetItemCount = function(id, includeBank)
      assert.is_true(includeBank)
      return counts[id] or 0
    end
    _G.GetInventoryItemLink = function(_, slot)
      return equipped[slot] and ("|Hitem:" .. slot .. "|h[Item]|h") or nil
    end
    _G.C_Item = {
      GetItemQualityByID = function(link)
        return equipped[tonumber(link:match("item:(%d+)"))]
      end,
    }
    det = env.add("Items")
  end)

  after_each(function()
    env.close()
  end)

  it("registers its two events, coalesced", function()
    det:Start()
    assert.are.same({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" }, det.registration.registered)
    assert.is_true(det.throttled.BAG_UPDATE_DELAYED)
    assert.is_true(det.throttled.PLAYER_EQUIPMENT_CHANGED)
  end)

  describe("item_obtained", function()
    it("publishes the count of the referenced items the player owns", function()
      counts[6948] = 3
      assert.are.same({ { type = "item_obtained", key = 6948, value = 3 } }, det:ItemFacts())
    end)

    it("publishes nothing for an item the player does not own or when the API is missing", function()
      counts[6948] = 0
      assert.are.same({}, det:ItemFacts())
      _G.GetItemCount = nil
      assert.are.same({}, det:ItemFacts())
    end)

    it("skips item keys that are not ids", function()
      env.ns.Catalog.Register({
        {
          id = "t_item_name",
          category = "general.misc",
          points = 5,
          scope = "character",
          icon = 1,
          retroactive = true,
          ref = {},
          criteria = { { type = "item_obtained", key = "Hearthstone", value = 1 } },
        },
      })
      assert.are.equal(1, #det:ItemFacts())
    end)

    it("updates on BAG_UPDATE_DELAYED and grants the achievement", function()
      env.useTimer()
      det:Start()
      env.fire(det, "BAG_UPDATE_DELAYED")
      env.fire(det, "BAG_UPDATE_DELAYED")
      assert.are.equal(1, #env.timers)
      assert.is_nil(env.h.earned("t_item_obtained"))
      env.flush()
      assert.are.equal(1, progress("item_obtained:6948"))
      assert.is_false(env.h.earned("t_item_obtained").retro)
    end)
  end)

  describe("equip_quality", function()
    it("counts the equipped slots at or above each quality", function()
      equipped = { [1] = 4, [2] = 3, [3] = 3, [5] = 2, [6] = 1, [7] = 0 }
      assert.are.same({
        { type = "equip_quality", key = 2, value = 4 },
        { type = "equip_quality", key = 3, value = 3 },
        { type = "equip_quality", key = 4, value = 1 },
      }, det:EquipFacts())
    end)

    it("leaves out the shirt and the tabard", function()
      equipped = { [4] = 4, [19] = 4, [1] = 4 }
      local facts = det:EquipFacts()
      assert.are.equal(1, facts[3].value)
    end)

    it("publishes nothing when no slot can be read", function()
      assert.are.same({}, det:EquipFacts())
      equipped = { [1] = 4 }
      _G.C_Item = nil
      assert.are.same({}, det:EquipFacts())
    end)

    it("counts a slot whose quality is only known to GetInventoryItemQuality", function()
      equipped = { [1] = 4 }
      _G.C_Item = nil
      _G.GetInventoryItemQuality = function()
        return 4
      end
      assert.are.equal(1, det:EquipFacts()[3].value)
    end)

    it("updates on PLAYER_EQUIPMENT_CHANGED and grants the achievement", function()
      det:Start()
      equipped = { [1] = 3, [2] = 4, [3] = 4, [5] = 4 }
      env.fire(det, "PLAYER_EQUIPMENT_CHANGED", 1, false)
      assert.are.equal(4, progress("equip_quality:3"))
      assert.are.equal(3, progress("equip_quality:4"))
      assert.is_false(env.h.earned("t_equip_quality").retro)
      assert.are.equal(3, env.app.stats:Get("epic_equipped"))
    end)
  end)

  it("answers the retro scan with both kinds of fact, silently", function()
    equipped = { [1] = 4, [2] = 4, [3] = 4, [5] = 3 }
    assert.are.equal(4, #det:Facts())
    det:Start()
    env.app.retro:Run()
    assert.is_true(env.h.earned("t_item_obtained").retro)
    assert.is_true(env.h.earned("t_equip_quality").retro)
  end)

  it("ignores an event it does not know", function()
    assert.has_no.errors(function()
      det:Handle("SOMETHING_ELSE")
    end)
  end)
end)

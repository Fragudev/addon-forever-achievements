local Env = dofile("tests/support/detector_env.lua")

describe("Exploration detector", function()
  local env, det, textures, areas

  before_each(function()
    env = Env.Build()
    -- Zone 12 has a reference total of 8 overlays; zone 13 declares none.
    env.ns.Catalog.Register({
      {
        id = "x_zone_half",
        category = "general.misc",
        points = 5,
        scope = "character",
        criteria = { { type = "explore_zone", key = 12, value = 50, total = 8 } },
      },
      {
        id = "x_zone_unknown",
        category = "general.misc",
        points = 5,
        scope = "character",
        criteria = { { type = "explore_zone", key = 13, value = 10 } },
      },
      {
        id = "x_zone_zero",
        category = "general.misc",
        points = 5,
        scope = "character",
        criteria = { { type = "explore_zone", key = 14, value = 10, total = 0 } },
      },
    })
    textures = { [12] = { {}, {}, {}, {}, {} }, [13] = { {}, {} }, [14] = { {} } }
    areas = { 7, 9 }
    _G.C_MapExplorationInfo = {
      GetExploredMapTextures = function(mapId)
        return textures[mapId]
      end,
      GetExploredAreaIDsAtPosition = function()
        return areas
      end,
    }
    _G.C_Map = {
      GetBestMapForUnit = function()
        return 12
      end,
      GetPlayerMapPosition = function()
        return {
          GetXY = function()
            return 0.4, 0.6
          end,
        }
      end,
    }
    det = env.add("Exploration")
  end)

  after_each(function()
    env.close()
  end)

  local function byKey(facts, factType, key)
    for _, fact in ipairs(facts) do
      if fact.type == factType and fact.key == key then
        return fact
      end
    end
    return nil
  end

  describe("retro provider", function()
    it("derives the explored share from the overlays and the catalog total", function()
      local facts = det:Facts()
      assert.are.equal(62, byKey(facts, "explore_zone", 12).value)
      assert.is_nil(byKey(facts, "explore_zone", 13))
      assert.is_nil(byKey(facts, "explore_zone", 14))
    end)

    it("caps the share at 100", function()
      textures[12] = { {}, {}, {}, {}, {}, {}, {}, {}, {}, {} }
      assert.are.equal(100, byKey(det:Facts(), "explore_zone", 12).value)
    end)

    it("gives the referenced areas explored at the player position", function()
      local facts = det:Facts()
      assert.are.equal(1, byKey(facts, "explore_area", 7).value)
      assert.is_nil(byKey(facts, "explore_area", 9))
    end)

    it("grants silently", function()
      det:Start()
      env.app.retro:Run()
      assert.is_true(env.h.earned("x_zone_half").retro)
      assert.is_true(env.h.earned("t_explore_area").retro)
    end)

    it("gives nothing when the exploration API is missing or raises", function()
      _G.C_MapExplorationInfo = nil
      assert.are.same({}, det:Facts())
      _G.C_MapExplorationInfo = {
        GetExploredMapTextures = function()
          error("boom")
        end,
        GetExploredAreaIDsAtPosition = function()
          error("boom")
        end,
      }
      assert.are.same({}, det:Facts())
    end)

    it("skips the areas when the position is unknown", function()
      _G.C_Map = nil
      assert.is_nil(byKey(det:Facts(), "explore_area", 7))
      _G.C_Map = {
        GetBestMapForUnit = function()
          return 12
        end,
      }
      assert.is_nil(byKey(det:Facts(), "explore_area", 7))
    end)

    it("skips the areas when the catalog references none", function()
      env.ns.Catalog.Reset()
      assert.are.same({}, det:Facts())
    end)
  end)

  describe("live", function()
    it("re-reads on MAP_EXPLORATION_UPDATED, coalesced", function()
      env.useTimer()
      det:Start()
      env.fire(det, "MAP_EXPLORATION_UPDATED")
      env.fire(det, "MAP_EXPLORATION_UPDATED")
      assert.are.equal(1, #env.timers)
      assert.is_nil(env.h.earned("x_zone_half"))
      env.flush()
      assert.is_false(env.h.earned("x_zone_half").retro)
      assert.are.equal(62, env.h.store:Progress("Player-1")["explore_zone:12"])
    end)
  end)
end)

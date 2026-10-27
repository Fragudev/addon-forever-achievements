local _, ns = ...

-- Exploration. Facts:
--   explore_zone  key = uiMapID, value = explored share of the map, 0..100
--   explore_area  key = area id, value 1, for the ids explored at the player's position
-- Only the maps and areas that the catalog references are read. Source (assumed, not measured):
-- C_MapExplorationInfo.GetExploredMapTextures, GetExploredAreaIDsAtPosition and MAP_EXPLORATION_UPDATED.
--
-- Mainline exposes only the EXPLORED overlays of a map, not how many the map has, so a percentage needs a reference
-- total. The catalog gives it in the criterion: { type = "explore_zone", key = uiMapID, value = 100, total = N },
-- where N is the overlay count of a fully explored map, measured in game. Without a total the map is skipped (no
-- guess). Each record returned by GetExploredMapTextures counts as one overlay.
--
-- Areas can only be asked at a position, so explore_area is checked for where the player stands (login and every
-- exploration update); it has no wider retroactive answer.
local Detector = ns.Detector
local Exploration = Detector.Class(
  "Exploration",
  { events = { "MAP_EXPLORATION_UPDATED" }, throttled = { MAP_EXPLORATION_UPDATED = true }, retroType = "explore_zone" }
)

-- { [uiMapID] = total } from the explore_zone criteria that declare one.
local function zoneTotals(catalog)
  local totals = {}
  for _, ach in ipairs(catalog.ByType("explore_zone")) do
    for _, criterion in ipairs(ach.criteria or {}) do
      if criterion.type == "explore_zone" and criterion.key ~= nil then
        if type(criterion.total) == "number" then
          totals[criterion.key] = criterion.total
        elseif totals[criterion.key] == nil then
          totals[criterion.key] = false
        end
      end
    end
  end
  return totals
end

function Exploration:ZoneFacts()
  local facts = {}
  for mapId, total in pairs(zoneTotals(self.app.catalog)) do
    local textures = total and total > 0 and self.platform.GetExploredMapTextures(mapId)
    if textures then
      local share = math.min(100, math.floor(#textures * 100 / total))
      facts[#facts + 1] = { type = "explore_zone", key = mapId, value = share }
    end
  end
  return facts
end

function Exploration:AreaFacts()
  local wanted = Detector.ReferencedKeys(self.app.catalog, "explore_area")
  if next(wanted) == nil then
    return {}
  end
  local mapId = self.platform.GetBestMapForPlayer()
  if not mapId then
    return {}
  end
  local x, y = self.platform.GetPlayerMapPosition(mapId)
  if not x then
    return {}
  end
  local facts = {}
  for _, areaId in ipairs(self.platform.GetExploredAreaIDsAtPosition(mapId, x, y) or {}) do
    if wanted[areaId] then
      facts[#facts + 1] = { type = "explore_area", key = areaId, value = 1 }
    end
  end
  return facts
end

function Exploration:Facts()
  local facts = self:ZoneFacts()
  for _, fact in ipairs(self:AreaFacts()) do
    facts[#facts + 1] = fact
  end
  return facts
end

function Exploration:Handle()
  self:Publish(self:Facts())
end

local _, ns = ...

-- Battlegrounds. Facts: bg_played and bg_win (key = the instance map id, value 1). Source (assumed, not measured):
--   * the map id is the 8th result of GetInstanceInfo while the instance type is "pvp" (Warsong Gulch 489, Arathi
--     Basin 529, Alterac Valley 30); arenas have another type and are ignored;
--   * a game is one stay in a battleground: bg_played goes out when the player is first seen inside it
--     (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA or UPDATE_BATTLEFIELD_STATUS) and the session ends when the player
--     is outside again;
--   * the game is won when GetBattlefieldWinner (0 Horde, 1 Alliance, nil while it runs) equals the player's faction,
--     checked on each UPDATE_BATTLEFIELD_STATUS; it counts once per game.
-- After a /reload inside a battleground the session is adopted without counting again. There is no retroactive answer.
local Detector = ns.Detector
local Battlegrounds = Detector.Class("Battlegrounds", {
  events = { "UPDATE_BATTLEFIELD_STATUS", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" },
})

-- The winner index of each faction token.
Battlegrounds.FACTION_INDEX = { Horde = 0, Alliance = 1 }

-- The map id of the battleground the player is in, or nil.
function Battlegrounds:Current()
  local info = self.platform.GetInstanceInfo()
  if info and info.instanceType == "pvp" and info.instanceID then
    return info.instanceID
  end
  return nil
end

-- After a reload inside a battleground: the game is already counted, and a finished one is already resolved.
function Battlegrounds:OnStart()
  local mapId = self:Current()
  if mapId then
    self.session = { mapId = mapId, resolved = self.platform.GetBattlefieldWinner() ~= nil }
  end
end

-- Keeps the session in step with the instance. Returns the map id and whether the session just began.
function Battlegrounds:Sync()
  local mapId = self:Current()
  if not mapId then
    self.session = nil
    return nil, false
  end
  if self.session and self.session.mapId == mapId then
    return mapId, false
  end
  self.session = { mapId = mapId, resolved = false }
  return mapId, true
end

-- true when the winner index is the player's faction.
function Battlegrounds:IsWinner(winner)
  local faction = self.platform.GetPlayerFaction()
  return faction ~= nil and Battlegrounds.FACTION_INDEX[faction] == winner
end

function Battlegrounds:Handle()
  local mapId, began = self:Sync()
  if not mapId then
    return
  end
  local facts = {}
  if began then
    facts[#facts + 1] = { type = "bg_played", key = mapId, value = 1 }
  elseif not self.session.resolved then
    local winner = self.platform.GetBattlefieldWinner()
    if winner then
      self.session.resolved = true
      if self:IsWinner(winner) then
        facts[#facts + 1] = { type = "bg_win", key = mapId, value = 1 }
      end
    end
  end
  if #facts > 0 then
    self:Publish(facts)
  end
end

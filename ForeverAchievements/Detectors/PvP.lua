local _, ns = ...

-- Honourable kills. Facts: honor_kills. Source (assumed, not measured): the first result of GetPVPLifetimeStats and
-- PLAYER_PVP_KILLS_CHANGED. Whether Forever answers is open (nrage issue #99); if the call is missing or gives
-- nothing, no fact is published. pvp_rank is not published: there is no readable source for it.
local Detector = ns.Detector
local PvP = Detector.Class("PvP", { events = { "PLAYER_PVP_KILLS_CHANGED" }, retroType = "honor_kills" })

function PvP:Facts()
  local kills = self.platform.GetPVPLifetimeStats()
  if not kills then
    return {}
  end
  return { { type = "honor_kills", value = kills } }
end

function PvP:Handle()
  self:Publish(self:Facts())
end

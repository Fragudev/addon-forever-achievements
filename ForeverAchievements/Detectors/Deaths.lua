local _, ns = ...

-- Deaths of the player. Facts: death (value 1 each). Source (assumed, not measured): PLAYER_DEAD. There is no
-- retroactive answer.
local Detector = ns.Detector
local Deaths = Detector.Class("Deaths", { events = { "PLAYER_DEAD" } })

function Deaths:Handle()
  self:Publish({ { type = "death", value = 1 } })
end

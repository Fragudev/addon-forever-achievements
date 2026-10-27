local _, ns = ...

-- Time played, in seconds. Facts: played. Source (assumed, not measured): RequestTimePlayed once per session and
-- TIME_PLAYED_MSG (total seconds, seconds at this level).
--
-- The client also prints the time played in chat for the request. Hiding that would mean touching the chat frames of
-- the Blizzard UI, which the addon does not do, so the line is left alone.
--
-- The answer arrives after the login scan, so the first answer of a session is fed as a retroactive grant (silent,
-- one summary line) and later answers (a manual /played) are live.
local Detector = ns.Detector
local Played = Detector.Class("Played", { events = { "TIME_PLAYED_MSG" }, retroType = "played" })

function Played:OnStart()
  if not self.requested then
    self.requested = true
    self.platform.RequestTimePlayed()
  end
end

-- Known only once the client has answered in this session.
function Played:Facts()
  if not self.total then
    return {}
  end
  return { { type = "played", value = self.total } }
end

function Played:SnapshotFields()
  if not self.total then
    return nil
  end
  return { played = self.total }
end

function Played:Handle(_, total)
  total = Detector.Number(total)
  if not total then
    return
  end
  local first = self.total == nil
  self.total = total
  local facts = self:Facts()
  if first and self.app.FeedRetro then
    self.app:FeedRetro(facts)
  else
    self:Publish(facts)
  end
  self:UpdateSnapshot({ played = total })
end

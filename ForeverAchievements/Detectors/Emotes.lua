local _, ns = ...

-- Emotes aimed at a creature. Facts: emote_target (key = "<EMOTE_TOKEN>:<npcID>", for example "LOVE:2442", value 1).
-- Source (assumed, not measured): a secure hook on DoEmote and, when the client has it, on C_ChatInfo.PerformEmote
-- (slash emotes may go through either; a call repeated within DEDUPE_SECONDS with the same token counts once). The
-- token is upper-cased; the NPC id is the sixth field of UnitGUID("target"), only for "Creature-..." GUIDs, so players,
-- pets and objects never count. Every emote, with or without a target, adds to the emotes_used statistic.
-- There is no retroactive answer.
local Detector = ns.Detector
local Emotes = Detector.Class("Emotes", { events = {} })

-- Two hook calls for the same emote closer than this are one emote.
Emotes.DEDUPE_SECONDS = 0.1

-- The npc id inside a creature GUID ("Creature-0-3-0-0-2442-0000ABCD12"), or nil.
function Emotes.NpcId(guid)
  if type(guid) ~= "string" then
    return nil
  end
  return tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
end

-- Installs the hooks. Records which ones took in `hooks`.
function Emotes:OnStart()
  local function handler(token)
    self:Emote(token)
  end
  self.hooks = {
    DoEmote = self.platform.HookSecure("DoEmote", handler),
    PerformEmote = self.platform.HookSecureMethod("C_ChatInfo", "PerformEmote", handler),
  }
end

-- true when this is the same emote as the last one, a moment ago.
function Emotes:IsRepeat(token)
  local now = self.platform.GetTime()
  local repeated = now ~= nil
    and self.lastToken == token
    and self.lastTime ~= nil
    and now - self.lastTime < Emotes.DEDUPE_SECONDS
  self.lastToken, self.lastTime = token, now
  return repeated
end

-- One emote performed by the player. Never raises: it runs inside a hook of a Blizzard function.
function Emotes:Emote(token)
  local ok, err = pcall(function()
    if type(token) ~= "string" or self.platform.IsSecret(token) or token == "" then
      return
    end
    token = token:upper()
    if self:IsRepeat(token) then
      return
    end
    if self.app.stats then
      self.app.stats:Increment("emotes_used")
    end
    local npc = Emotes.NpcId(self.platform.GetUnitGUID("target"))
    if npc then
      self:Publish({ { type = "emote_target", key = token .. ":" .. npc, value = 1 } })
    end
  end)
  if not ok then
    self.lastError = tostring(err)
  end
end

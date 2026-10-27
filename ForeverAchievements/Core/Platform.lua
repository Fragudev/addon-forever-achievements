local _, ns = ...

-- Single seam over the WoW client API. Everything else asks Platform, so specs can substitute a fake and API
-- changes between Mainline and Forever stay in one file.
--
-- Every wrapper follows one contract: it gives nil (or an empty table where the comment says so) when the API is
-- missing on this client, raises, or returns a secret value (Midnight restriction: a secret cannot be compared,
-- stored or measured). The caller then treats the data as unavailable. Nothing here raises.
local Platform = {}

-- Stands in for a secret value in the packed results of Platform.Invoke. Wrappers turn it into nil.
Platform.SECRET = setmetatable({}, {
  __tostring = function()
    return "<secret>"
  end,
})
local SECRET = Platform.SECRET

-- Events the addon must never register: the client blocks the whole addon for them ("blocked from an action only
-- available to the Blizzard UI", measured in nrage).
local FORBIDDEN_EVENTS = { COMBAT_LOG_EVENT_UNFILTERED = true }

-- true when `value` is a secret value. Uses issecretvalue when the client has it; otherwise relies on the fact that a
-- secret raises when it is compared or measured.
function Platform.IsSecret(value)
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, value)
    if ok and secret then
      return true
    end
  end
  local kind = type(value)
  if kind == "number" then
    return not pcall(function()
      return value >= 0
    end)
  elseif kind == "string" then
    return not pcall(function()
      return #value
    end)
  end
  return false
end

-- The function at a dotted global path ("C_QuestLog.GetAllCompletedQuestIDs"), or nil when any step is missing.
function Platform.Resolve(path)
  local target = _G
  for part in path:gmatch("[^.]+") do
    if type(target) ~= "table" then
      return nil
    end
    target = target[part]
  end
  if type(target) == "function" then
    return target
  end
  return nil
end

-- true when the API at `path` exists on this client.
function Platform.Has(path)
  return Platform.Resolve(path) ~= nil
end

local function pack(...)
  return { n = select("#", ...), ... }
end

local function safeText(value)
  local ok, text = pcall(tostring, value)
  if ok and type(text) == "string" then
    return text
  end
  return "<secret>"
end

-- Calls the API at `path` through pcall. Gives "missing", "error" with the message, or "ok" with the packed results
-- ({ n = count, ... }, each secret value replaced by Platform.SECRET).
function Platform.Invoke(path, ...)
  local fn = Platform.Resolve(path)
  if not fn then
    return "missing"
  end
  local packed = pack(pcall(fn, ...))
  if not packed[1] then
    return "error", safeText(packed[2])
  end
  local count = packed.n - 1
  local results = { n = count }
  for index = 1, count do
    local value = packed[index + 1]
    if Platform.IsSecret(value) then
      value = SECRET
    end
    results[index] = value
  end
  return "ok", results
end

-- The packed results of a call, or nil when it is missing or raised.
local function results(path, ...)
  local status, packed = Platform.Invoke(path, ...)
  if status == "ok" then
    return packed
  end
  return nil
end

-- A value of the expected Lua type, or nil (a secret never matches).
local function typedValue(value, kind)
  if value ~= SECRET and type(value) == kind then
    return value
  end
  return nil
end

-- The first result of the call when it has the expected type.
local function first(kind, path, ...)
  local packed = results(path, ...)
  if not packed then
    return nil
  end
  return typedValue(packed[1], kind)
end

-- The first results of the call, each one kept only when it has the expected type: kinds = { "string", "number" }.
local function several(kinds, path, ...)
  local packed = results(path, ...)
  if not packed then
    return nil
  end
  local values = {}
  for index = 1, #kinds do
    values[index] = typedValue(packed[index], kinds[index])
  end
  return unpack(values, 1, #kinds)
end

-- Unit and character -------------------------------------------------------------------------------------------

function Platform.GetPlayerLevel()
  return first("number", "UnitLevel", "player")
end

-- The identity of a character is its GUID: UnitName gives only the first word of a multi-word name on Forever.
function Platform.GetPlayerGUID()
  return first("string", "UnitGUID", "player")
end

-- First word of the name only (measured in nrage). Display use at most, never an identity.
function Platform.GetPlayerName()
  return first("string", "UnitName", "player")
end

function Platform.GetPlayerFullName()
  return first("string", "GetUnitName", "player", true)
end

-- The name to show for the player. GetUnitName without the realm is preferred because UnitName gives only the first
-- word of a multi-word name on Forever (measured in nrage); UnitName is the fallback. Display use only.
function Platform.GetPlayerDisplayName()
  return first("string", "GetUnitName", "player", false) or first("string", "UnitName", "player")
end

-- Localized class name, class token ("WARRIOR"), class id.
function Platform.GetPlayerClass()
  return several({ "string", "string", "number" }, "UnitClass", "player")
end

-- Localized race name, race token, race id.
function Platform.GetPlayerRace()
  return several({ "string", "string", "number" }, "UnitRace", "player")
end

-- Faction token ("Alliance" or "Horde"), localized faction name.
function Platform.GetPlayerFaction()
  return several({ "string", "string" }, "UnitFactionGroup", "player")
end

function Platform.GetRealmName()
  return first("string", "GetNormalizedRealmName")
end

-- Money and time played ----------------------------------------------------------------------------------------

-- Copper.
function Platform.GetMoney()
  return first("number", "GetMoney")
end

-- Asks for the time played; the answer arrives as TIME_PLAYED_MSG (total seconds, level seconds). The client also
-- prints it in chat. true when the request was made.
function Platform.RequestTimePlayed()
  local status = Platform.Invoke("RequestTimePlayed")
  return status == "ok"
end

-- Quests --------------------------------------------------------------------------------------------------------

-- Array of completed quest ids, or an EMPTY table when the API is missing or fails (callers cannot tell "none" from
-- "unavailable" here; use Platform.Has when that matters).
function Platform.GetCompletedQuestIDs()
  return first("table", "C_QuestLog.GetAllCompletedQuestIDs") or {}
end

-- Same list, but nil (not an empty table) when the API is missing, fails or gives a secret: lets a caller tell "no
-- quest completed" from "cannot read".
function Platform.ReadCompletedQuestIDs()
  return first("table", "C_QuestLog.GetAllCompletedQuestIDs")
end

-- true or false, nil when the client cannot say.
function Platform.IsQuestCompleted(questId)
  return first("boolean", "C_QuestLog.IsQuestFlaggedCompleted", questId)
end

-- Maps and exploration ------------------------------------------------------------------------------------------

function Platform.GetBestMapForPlayer()
  return first("number", "C_Map.GetBestMapForUnit", "player")
end

-- { name, mapType, parentMapID } or nil.
function Platform.GetMapInfo(mapId)
  local info = first("table", "C_Map.GetMapInfo", mapId)
  if not info then
    return nil
  end
  local name = typedValue(info.name, "string")
  if not name then
    return nil
  end
  return {
    name = name,
    mapType = typedValue(info.mapType, "number"),
    parentMapID = typedValue(info.parentMapID, "number"),
  }
end

-- Normalized x, y of the player on `mapId`, or nil.
function Platform.GetPlayerMapPosition(mapId)
  local position = first("table", "C_Map.GetPlayerMapPosition", mapId, "player")
  if not position or type(position.GetXY) ~= "function" then
    return nil
  end
  local ok, x, y = pcall(position.GetXY, position)
  if ok and typedValue(x, "number") and typedValue(y, "number") then
    return x, y
  end
  return nil
end

-- Array of explored area ids at a normalized position of a map, or nil.
function Platform.GetExploredAreaIDsAtPosition(mapId, x, y)
  if not CreateVector2D then
    return nil
  end
  local ok, vector = pcall(CreateVector2D, x, y)
  if not ok then
    return nil
  end
  return first("table", "C_MapExplorationInfo.GetExploredAreaIDsAtPosition", mapId, vector)
end

-- Array of explored map texture records, or nil.
function Platform.GetExploredMapTextures(mapId)
  return first("table", "C_MapExplorationInfo.GetExploredMapTextures", mapId)
end

-- Reputation ----------------------------------------------------------------------------------------------------

-- { name, factionID, standingID, barMin, barMax, barValue, source } or nil. Prefers C_Reputation.GetFactionDataByID
-- and falls back to the older GetFactionInfoByID.
function Platform.GetFactionData(factionId)
  local data = first("table", "C_Reputation.GetFactionDataByID", factionId)
  if data and typedValue(data.name, "string") then
    return {
      name = data.name,
      factionID = typedValue(data.factionID, "number"),
      standingID = typedValue(data.reaction, "number"),
      barMin = typedValue(data.currentReactionThreshold, "number"),
      barMax = typedValue(data.nextReactionThreshold, "number"),
      barValue = typedValue(data.currentStanding, "number"),
      source = "C_Reputation.GetFactionDataByID",
    }
  end
  local name, _, standingId, barMin, barMax, barValue =
    several({ "string", "string", "number", "number", "number", "number" }, "GetFactionInfoByID", factionId)
  if name then
    return {
      name = name,
      factionID = factionId,
      standingID = standingId,
      barMin = barMin,
      barMax = barMax,
      barValue = barValue,
      source = "GetFactionInfoByID",
    }
  end
  return nil
end

function Platform.GetNumFactions()
  return first("number", "C_Reputation.GetNumFactions") or first("number", "GetNumFactions")
end

-- { name, factionID, standingID, barMin, barMax, barValue, source } of the faction at a position of the faction list,
-- or nil. The list only has the rows that are visible (collapsed headers hide their factions); the addon never
-- expands them. Prefers C_Reputation.GetFactionDataByIndex and falls back to GetFactionInfo.
function Platform.GetFactionByIndex(index)
  local data = first("table", "C_Reputation.GetFactionDataByIndex", index)
  if data and typedValue(data.name, "string") then
    return {
      name = data.name,
      factionID = typedValue(data.factionID, "number"),
      standingID = typedValue(data.reaction, "number"),
      barMin = typedValue(data.currentReactionThreshold, "number"),
      barMax = typedValue(data.nextReactionThreshold, "number"),
      barValue = typedValue(data.currentStanding, "number"),
      source = "C_Reputation.GetFactionDataByIndex",
    }
  end
  local packed = results("GetFactionInfo", index)
  if packed and typedValue(packed[1], "string") then
    return {
      name = packed[1],
      factionID = typedValue(packed[14], "number"),
      standingID = typedValue(packed[3], "number"),
      barMin = typedValue(packed[4], "number"),
      barMax = typedValue(packed[5], "number"),
      barValue = typedValue(packed[6], "number"),
      source = "GetFactionInfo",
    }
  end
  return nil
end

-- Professions ---------------------------------------------------------------------------------------------------

-- Array of profession indexes (primary 1, primary 2, archaeology, fishing, cooking), without the empty slots.
function Platform.GetProfessions()
  local packed = results("GetProfessions")
  local list = {}
  if packed then
    for index = 1, packed.n do
      if typedValue(packed[index], "number") then
        list[#list + 1] = packed[index]
      end
    end
  end
  return list
end

-- { name, rank, maxRank, skillLine } of a profession index, or nil.
function Platform.GetProfessionInfo(index)
  local name, _, rank, maxRank, _, _, skillLine =
    several({ "string", "string", "number", "number", "number", "number", "number" }, "GetProfessionInfo", index)
  if not name then
    return nil
  end
  return { name = name, rank = rank, maxRank = maxRank, skillLine = skillLine }
end

-- Collections ---------------------------------------------------------------------------------------------------

function Platform.GetNumMounts()
  return first("number", "C_MountJournal.GetNumMounts")
end

-- Array of mount ids, or nil.
function Platform.GetMountIDs()
  return first("table", "C_MountJournal.GetMountIDs")
end

-- How many mounts the player has collected: walks the journal ids and reads the "is collected" flag (11th result of
-- C_MountJournal.GetMountInfoByID). nil when the journal is missing or no mount could be read.
function Platform.GetCollectedMountCount()
  local ids = Platform.GetMountIDs()
  if not ids then
    return nil
  end
  if #ids == 0 then
    return 0
  end
  local readable, collected = 0, 0
  for _, id in ipairs(ids) do
    local packed = results("C_MountJournal.GetMountInfoByID", id)
    local flag = packed and typedValue(packed[11], "boolean")
    if flag ~= nil then
      readable = readable + 1
      if flag then
        collected = collected + 1
      end
    end
  end
  if readable == 0 then
    return nil
  end
  return collected
end

-- Total pets, owned pets.
function Platform.GetNumPets()
  return several({ "number", "number" }, "C_PetJournal.GetNumPets")
end

function Platform.GetNumLearnedToys()
  return first("number", "C_ToyBox.GetNumLearnedDisplayedToys")
end

-- PvP -----------------------------------------------------------------------------------------------------------

-- Lifetime honourable kills, then the next two values as the client gives them (not measured on Forever, issue #99).
function Platform.GetPVPLifetimeStats()
  return several({ "number", "number", "number" }, "GetPVPLifetimeStats")
end

-- Winning faction index of the finished battleground (0 Horde, 1 Alliance), or nil.
function Platform.GetBattlefieldWinner()
  return first("number", "GetBattlefieldWinner")
end

-- Items ---------------------------------------------------------------------------------------------------------

function Platform.GetItemCount(item, includeBank)
  return first("number", "GetItemCount", item, includeBank)
end

-- Item link of an equipped slot, or nil (empty slot, secret link, no API).
function Platform.GetInventoryItemLink(slot)
  return first("string", "GetInventoryItemLink", "player", slot)
end

function Platform.GetItemQuality(itemId)
  return first("number", "C_Item.GetItemQualityByID", itemId)
end

-- Quality (0 poor .. 4 epic) of the item equipped in an inventory slot, or nil for an empty slot, an unreadable link
-- or no API. Reads the link first so an empty slot is told from an unreadable one; falls back to
-- GetInventoryItemQuality when C_Item.GetItemQualityByID does not answer.
function Platform.GetEquippedItemQuality(slot)
  local link = Platform.GetInventoryItemLink(slot)
  if not link then
    return nil
  end
  return Platform.GetItemQuality(link) or first("number", "GetInventoryItemQuality", "player", slot)
end

-- Units and instances --------------------------------------------------------------------------------------------

-- The GUID of any unit token ("target"), or nil.
function Platform.GetUnitGUID(unit)
  return first("string", "UnitGUID", unit)
end

-- { name, instanceType, difficultyID, instanceID } of the current instance (GetInstanceInfo: 1st, 2nd, 3rd and 8th
-- results), or nil when the call is missing or answers nothing readable. instanceType is "none", "party", "raid",
-- "pvp", "arena" ...; instanceID is the map id of the instance.
function Platform.GetInstanceInfo()
  local name, instanceType, difficultyID, _, _, _, _, instanceID =
    several({ "string", "string", "number", "string", "number", "number", "boolean", "number" }, "GetInstanceInfo")
  if not instanceType then
    return nil
  end
  return { name = name, instanceType = instanceType, difficultyID = difficultyID, instanceID = instanceID }
end

-- true while a boss encounter is in progress, false when it is not, nil when the client cannot say.
function Platform.IsEncounterInProgress()
  return first("boolean", "IsEncounterInProgress")
end

-- Seconds since the client started, with millisecond precision (GetTime), or nil.
function Platform.GetTime()
  return first("number", "GetTime")
end

-- The global string `name` (a localized format such as GOLD_AMOUNT), or nil when it is missing, not a string or secret.
function Platform.GetGlobalString(name)
  local value = _G[name]
  if value ~= nil and not Platform.IsSecret(value) and type(value) == "string" then
    return value
  end
  return nil
end

-- Client state --------------------------------------------------------------------------------------------------

function Platform.GetServerTime()
  return first("number", "GetServerTime")
end

function Platform.GetLocale()
  return first("string", "GetLocale")
end

-- inInstance (boolean), instanceType ("none", "party", "raid", "pvp", ...), or nil.
function Platform.IsInInstance()
  return several({ "boolean", "string" }, "IsInInstance")
end

-- true while the client blocks chat messaging (an encounter), false when it does not, nil when it cannot say.
function Platform.IsChatMessagingLockedDown()
  return first("boolean", "C_ChatInfo.InChatMessagingLockdown")
end

-- Native achievement system (the key risk in plan section 2) ------------------------------------------------------

-- Array of category ids, EMPTY when the API is missing or fails.
function Platform.GetAchievementCategories()
  return first("table", "GetCategoryList") or {}
end

function Platform.GetTotalAchievementPoints()
  return first("number", "GetTotalAchievementPoints")
end

-- Completed achievements, then the total the client knows.
function Platform.GetNumCompletedAchievements()
  local completed, total = several({ "number", "number" }, "GetNumCompletedAchievements")
  return completed, total
end

-- A new frame for the events of one detector, or nil when the client cannot make it.
function Platform.NewFrame()
  if type(CreateFrame) ~= "function" then
    return nil
  end
  local ok, frame = pcall(CreateFrame, "Frame")
  if ok and type(frame) == "table" then
    return frame
  end
  return nil
end

-- Runs `fn` after `seconds` (C_Timer.After). false when the client has no timer, so the caller can run it at once.
function Platform.After(seconds, fn)
  return (Platform.Invoke("C_Timer.After", seconds, fn)) == "ok"
end

-- Hooks and events ----------------------------------------------------------------------------------------------

-- Hooks a global function without tainting it (hooksecurefunc). false when the client has no hooksecurefunc or the
-- function to hook does not exist.
function Platform.HookSecure(name, handler)
  if not hooksecurefunc or not Platform.Has(name) then
    return false
  end
  return pcall(hooksecurefunc, name, handler)
end

-- Hooks a function that lives in a table ("C_ChatInfo", "PerformEmote") without tainting it. false when the client has
-- no hooksecurefunc, the table or the function is missing, or the hook is refused.
function Platform.HookSecureMethod(tablePath, name, handler)
  if not hooksecurefunc or not Platform.Has(tablePath .. "." .. name) then
    return false
  end
  local target = _G
  for part in tablePath:gmatch("[^.]+") do
    target = target[part]
  end
  return pcall(hooksecurefunc, target, name, handler)
end

-- Registers `event` on `frame`; false when the client refuses it (an unknown event or a restricted one). The combat
-- log event is never registered, whoever asks.
function Platform.TryRegisterEvent(frame, event)
  if FORBIDDEN_EVENTS[event] then
    return false
  end
  local ok = pcall(frame.RegisterEvent, frame, event)
  return ok
end

-- Registers every event of the list. Gives { registered = { names }, refused = { names } }, in list order.
function Platform.RegisterEvents(frame, events)
  local outcome = { registered = {}, refused = {} }
  for _, event in ipairs(events) do
    local bucket = Platform.TryRegisterEvent(frame, event) and outcome.registered or outcome.refused
    bucket[#bucket + 1] = event
  end
  return outcome
end

-- Every client API the addon relies on. Each entry is a group of alternatives: the group is satisfied when any
-- member exists. /fach debug selftest walks this list.
Platform.REQUIRED_APIS = {
  { "UnitLevel" },
  { "UnitGUID" },
  { "UnitName" },
  { "GetUnitName" },
  { "UnitClass" },
  { "UnitRace" },
  { "UnitFactionGroup" },
  { "GetNormalizedRealmName" },
  { "GetMoney" },
  { "RequestTimePlayed" },
  { "C_QuestLog.GetAllCompletedQuestIDs" },
  { "C_QuestLog.IsQuestFlaggedCompleted" },
  { "C_MapExplorationInfo.GetExploredAreaIDsAtPosition" },
  { "C_MapExplorationInfo.GetExploredMapTextures" },
  { "C_Map.GetBestMapForUnit" },
  { "C_Map.GetMapInfo" },
  { "C_Reputation.GetFactionDataByID", "GetFactionInfoByID" },
  { "C_Reputation.GetNumFactions", "GetNumFactions" },
  { "GetProfessions" },
  { "GetProfessionInfo" },
  { "C_MountJournal.GetNumMounts" },
  { "C_MountJournal.GetMountIDs" },
  { "C_PetJournal.GetNumPets" },
  { "C_ToyBox.GetNumLearnedDisplayedToys" },
  { "GetPVPLifetimeStats" },
  { "GetBattlefieldWinner" },
  { "GetItemCount" },
  { "GetInventoryItemLink" },
  { "C_Item.GetItemQualityByID", "GetInventoryItemQuality" },
  { "GetInstanceInfo" },
  { "IsEncounterInProgress" },
  { "GetTime" },
  { "DoEmote", "C_ChatInfo.PerformEmote" },
  { "GetServerTime" },
  { "GetLocale" },
  { "IsInInstance" },
  { "C_ChatInfo.InChatMessagingLockdown" },
  { "hooksecurefunc" },
}

ns.Platform = Platform

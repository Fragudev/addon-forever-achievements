local _, ns = ...

-- Phase 1 API probe: finds out which client APIs and events Forever really gives us, so the catalogue only holds
-- achievements that can be detected reliably (plan sections 2 and 5.2). Every result is documented in
-- docs/API_NOTES.md once the owner has run it in game.
--
-- Usage: /fach debug probe          one line per API, in a stable key=value format
--        /fach debug probe events   the events captured since login: event, count, last arguments
--        /fach debug selftest       which APIs the addon relies on exist
-- Nothing here raises: every call goes through Platform (pcall) and nothing divides.
local Platform = ns.Platform
local Probe = {}

local MAX_TEXT = 160
local MAX_EVENTS = 64
local MAX_SAVED_LINES = 200
-- Stable ids for the probe questions: Stormwind reputation, the Hearthstone, main-hand slot, "Level 10" achievement.
local PROBE_FACTION_ID = 72
local PROBE_ITEM_ID = 6948
local PROBE_SLOT = 16
local PROBE_ACHIEVEMENT_ID = 6

-- Events to probe. Never COMBAT_LOG_EVENT_UNFILTERED: registering it blocks the addon (Platform refuses it too).
Probe.EVENTS = {
  -- Character and progress
  "PLAYER_LEVEL_UP",
  "PLAYER_MONEY",
  "TIME_PLAYED_MSG",
  "QUEST_TURNED_IN",
  "MAP_EXPLORATION_UPDATED",
  "UPDATE_FACTION",
  "SKILL_LINES_CHANGED",
  -- Encounters (every argument is logged)
  "ENCOUNTER_START",
  "ENCOUNTER_END",
  -- PvP
  "PLAYER_PVP_KILLS_CHANGED",
  "UPDATE_BATTLEFIELD_STATUS",
  -- Other
  "PLAYER_DEAD",
  "BAG_UPDATE_DELAYED",
  "CHAT_MSG_MONEY",
  "NEW_MOUNT_ADDED",
  -- Native achievements
  "ACHIEVEMENT_EARNED",
  "CRITERIA_UPDATE",
  -- Session
  "PLAYER_LOGOUT",
}

-- A short readable text for any value; "<secret>" for a value that cannot be read. Never raises.
local function describeScalar(value)
  if value == Platform.SECRET or Platform.IsSecret(value) then
    return "<secret>"
  end
  local kind = type(value)
  if kind == "table" then
    return "table"
  end
  local text = tostring(value)
  if #text > 80 then
    text = text:sub(1, 77) .. "..."
  end
  return text
end

local function describeTable(value)
  local count = #value
  if count > 0 then
    local sample = {}
    for index = 1, math.min(count, 5) do
      sample[index] = describeScalar(value[index])
    end
    return ("table n=%d first5=%s"):format(count, table.concat(sample, ","))
  end
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  if #keys == 0 then
    return "table empty"
  end
  table.sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)
  local parts = {}
  for index = 1, math.min(#keys, 8) do
    parts[index] = tostring(keys[index]) .. "=" .. describeScalar(value[keys[index]])
  end
  local more = #keys > 8 and (" +" .. (#keys - 8) .. " more") or ""
  return "table {" .. table.concat(parts, " ") .. "}" .. more
end

local function describe(value)
  local ok, text = pcall(function()
    if type(value) == "table" and value ~= Platform.SECRET then
      return describeTable(value)
    end
    return describeScalar(value)
  end)
  return ok and text or "<secret>"
end

local function describeResults(packed)
  if packed.n == 0 then
    return "(no values)"
  end
  local parts = {}
  for index = 1, packed.n do
    parts[index] = describe(packed[index])
  end
  return table.concat(parts, ", ")
end

local function describeArgs(args)
  local parts = {}
  for index, value in ipairs(args) do
    parts[index] = describeScalar(value)
  end
  return table.concat(parts, ",")
end

-- Probe items ---------------------------------------------------------------------------------------------------
-- { api, question, args = list or function(ctx) -> list|nil, after = function(ctx, results),
--   run = function(ctx) -> text }
-- `ctx` carries what earlier items found (the map, a quest id, a profession) so later items can use it.

local function numberAt(packed, index)
  local value = packed[index]
  if value ~= Platform.SECRET and type(value) == "number" then
    return value
  end
  return nil
end

Probe.ITEMS = {
  { api = "UnitLevel", question = "Is the player level readable?", args = { "player" } },
  { api = "UnitGUID", question = "Is the player GUID readable (the identity of a character)?", args = { "player" } },
  { api = "UnitName", question = "What does UnitName give for a multi-word name?", args = { "player" } },
  { api = "GetUnitName", question = "Does GetUnitName give the full name?", args = { "player", true } },
  { api = "UnitClass", question = "Class name, token and id?", args = { "player" } },
  { api = "UnitRace", question = "Race name, token and id?", args = { "player" } },
  { api = "UnitFactionGroup", question = "Faction token?", args = { "player" } },
  { api = "GetNormalizedRealmName", question = "Normalized realm name?", args = {} },
  { api = "GetMoney", question = "Is the money (copper) readable?", args = {} },
  {
    api = "RequestTimePlayed",
    question = "Does it fire TIME_PLAYED_MSG (check the events report)?",
    args = {},
  },
  {
    api = "C_QuestLog.GetAllCompletedQuestIDs",
    question = "Does it list the completed quests (retroactive quest achievements)?",
    args = {},
    after = function(ctx, packed)
      local list = packed[1]
      if type(list) == "table" and list ~= Platform.SECRET then
        ctx.questId = list[1]
      end
    end,
  },
  {
    api = "C_QuestLog.IsQuestFlaggedCompleted",
    question = "Does it answer for a completed quest id?",
    args = function(ctx)
      return { ctx.questId or 1 }
    end,
  },
  {
    api = "C_Map.GetBestMapForUnit",
    question = "Which map is the player on?",
    args = { "player" },
    after = function(ctx, packed)
      ctx.mapId = numberAt(packed, 1)
    end,
  },
  {
    api = "C_Map.GetMapInfo",
    question = "Are the map name, type and parent readable?",
    args = function(ctx)
      return ctx.mapId and { ctx.mapId } or nil
    end,
  },
  {
    api = "C_Map.GetPlayerMapPosition",
    question = "Is the player position on the map readable?",
    args = function(ctx)
      return ctx.mapId and { ctx.mapId, "player" } or nil
    end,
    after = function(ctx, packed)
      local position = packed[1]
      if type(position) == "table" and position ~= Platform.SECRET and type(position.GetXY) == "function" then
        local ok, x, y = pcall(position.GetXY, position)
        if ok then
          ctx.x, ctx.y = x, y
        end
      end
    end,
  },
  {
    api = "C_MapExplorationInfo.GetExploredAreaIDsAtPosition",
    question = "Does it say which areas are explored at a position (exploration achievements)?",
    args = function(ctx)
      if ctx.mapId and ctx.x and ctx.y and CreateVector2D then
        return { ctx.mapId, CreateVector2D(ctx.x, ctx.y) }
      end
      return nil
    end,
  },
  {
    api = "C_MapExplorationInfo.GetExploredMapTextures",
    question = "Does it list the explored map textures of a map?",
    args = function(ctx)
      return ctx.mapId and { ctx.mapId } or nil
    end,
  },
  {
    api = "C_Reputation.GetFactionDataByID",
    question = "Does the modern reputation API answer for a faction id?",
    args = { PROBE_FACTION_ID },
  },
  { api = "GetFactionInfoByID", question = "Does the old reputation API answer?", args = { PROBE_FACTION_ID } },
  { api = "C_Reputation.GetNumFactions", question = "How many factions are listed?", args = {} },
  { api = "GetNumFactions", question = "How many factions (old API)?", args = {} },
  {
    api = "GetProfessions",
    question = "Which profession indexes does the player have?",
    args = {},
    after = function(ctx, packed)
      for index = 1, packed.n do
        if numberAt(packed, index) then
          ctx.profession = packed[index]
          return
        end
      end
    end,
  },
  {
    api = "GetProfessionInfo",
    question = "Are the profession name and skill level readable?",
    args = function(ctx)
      return ctx.profession and { ctx.profession } or nil
    end,
  },
  { api = "C_MountJournal.GetNumMounts", question = "Does the mount journal exist on Forever?", args = {} },
  { api = "C_MountJournal.GetMountIDs", question = "Does it list the mount ids?", args = {} },
  { api = "C_PetJournal.GetNumPets", question = "Does the pet journal exist (total, owned)?", args = {} },
  {
    api = "C_ToyBox.GetNumLearnedDisplayedToys",
    question = "Does the toy box exist on Forever?",
    args = {},
  },
  { api = "GetPVPLifetimeStats", question = "Does it give lifetime honourable kills (issue #99)?", args = {} },
  { api = "GetBattlefieldWinner", question = "What does it give outside a battleground?", args = {} },
  { api = "GetItemCount", question = "Does it count an item (the Hearthstone)?", args = { PROBE_ITEM_ID } },
  {
    api = "GetInventoryItemLink",
    question = "Is the equipped item link readable?",
    args = { "player", PROBE_SLOT },
  },
  { api = "C_Item.GetItemQualityByID", question = "Does it give an item quality by id?", args = { PROBE_ITEM_ID } },
  { api = "GetServerTime", question = "Is the server time readable?", args = {} },
  { api = "GetLocale", question = "Which locale does the client report?", args = {} },
  { api = "IsInInstance", question = "Does it report the instance type?", args = {} },
  {
    api = "C_ChatInfo.InChatMessagingLockdown",
    question = "Is the chat lockdown state readable?",
    args = {},
  },
  {
    api = "hooksecurefunc",
    question = "Can DoEmote be hooked (emote achievements)?",
    run = function()
      return ("present=%s DoEmote=%s hooked=%s"):format(
        tostring(Platform.Has("hooksecurefunc")),
        tostring(Platform.Has("DoEmote")),
        tostring(Probe.hooked == true)
      )
    end,
  },
  {
    api = "C_AchievementInfo",
    question = "Does the native achievement namespace exist, and which functions?",
    run = function()
      local namespace = type(_G.C_AchievementInfo) == "table" and _G.C_AchievementInfo or nil
      if not namespace then
        return "missing"
      end
      local names = {}
      for key, value in pairs(namespace) do
        if type(value) == "function" then
          names[#names + 1] = tostring(key)
        end
      end
      table.sort(names)
      return ("present functions=%d %s"):format(#names, table.concat(names, ","))
    end,
  },
  {
    api = "GetAchievementInfo",
    question = "Does the native achievement lookup answer (id 6)?",
    args = { PROBE_ACHIEVEMENT_ID },
  },
  { api = "GetCategoryList", question = "Is the native achievement category list non-empty?", args = {} },
  { api = "GetNumCompletedAchievements", question = "What does the native completed count say?", args = {} },
  { api = "GetTotalAchievementPoints", question = "What do the native achievement points say?", args = {} },
}

-- The item key as printed: the API plus its arguments, e.g. GetItemCount(6948).
local function itemKey(item, args)
  if args and #args > 0 then
    return item.api .. "(" .. describeArgs(args) .. ")"
  end
  return item.api
end

-- Runs one item; gives the printed value. Never raises.
local function runItem(item, ctx)
  if item.run then
    local ok, text = pcall(item.run, ctx)
    return item.api, ok and text or ("error: " .. tostring(text))
  end
  local args = item.args
  if type(args) == "function" then
    args = args(ctx)
  end
  if not args then
    return item.api, "skipped: needs an earlier result"
  end
  local status, packed = Platform.Invoke(item.api, unpack(args))
  local key = itemKey(item, args)
  if status ~= "ok" then
    return key, status == "error" and ("error: " .. tostring(packed)) or "missing"
  end
  if item.after then
    pcall(item.after, ctx, packed)
  end
  return key, describeResults(packed)
end

local function nativeVerdict()
  local hasInfo = Platform.Has("GetAchievementInfo")
  local categories = #Platform.GetAchievementCategories()
  local points = Platform.GetTotalAchievementPoints()
  local completed = Platform.GetNumCompletedAchievements()
  local present = hasInfo or categories > 0 or type(_G.C_AchievementInfo) == "table"
  return ("native_achievements=%s categories=%d points=%s completed=%s"):format(
    present and "present" or "absent",
    categories,
    tostring(points),
    tostring(completed)
  )
end

-- Event log -----------------------------------------------------------------------------------------------------

Probe.log = {}
Probe.logOrder = {}
Probe.registration = nil
Probe.hooked = false

-- The arguments of an event as one bounded text.
local function argsText(...)
  local count = select("#", ...)
  if count == 0 then
    return "-"
  end
  local parts = {}
  for index = 1, count do
    parts[index] = describe((select(index, ...)))
  end
  local text = table.concat(parts, ",")
  if #text > MAX_TEXT then
    text = text:sub(1, MAX_TEXT - 3) .. "..."
  end
  return text
end

-- Counts an event and keeps its last arguments. The log holds at most MAX_EVENTS distinct events.
function Probe.Record(event, ...)
  local entry = Probe.log[event]
  if not entry then
    if #Probe.logOrder >= MAX_EVENTS then
      return
    end
    entry = { count = 0, last = "-" }
    Probe.log[event] = entry
    Probe.logOrder[#Probe.logOrder + 1] = event
  end
  entry.count = entry.count + 1
  entry.last = argsText(...)
end

-- Debug data kept in ForeverAchievementsDB.debug (bounded): probeEvents = { [event] = { count, last } } written at
-- PLAYER_LOGOUT, and lastProbe = the lines of the last /fach debug probe. Gone with the next clean schema.
local function debugTable()
  if type(ns.db) ~= "table" then
    return nil
  end
  ns.db.debug = ns.db.debug or {}
  return ns.db.debug
end

function Probe.Persist()
  local debug = debugTable()
  if not debug then
    return false
  end
  local saved = {}
  for _, event in ipairs(Probe.logOrder) do
    saved[event] = { count = Probe.log[event].count, last = Probe.log[event].last }
  end
  debug.probeEvents = saved
  return true
end

local function onEvent(_, event, ...)
  Probe.Record(event, ...)
  if event == "PLAYER_LOGOUT" then
    pcall(Probe.Persist)
  end
end

-- Registers the probe events and hooks DoEmote. Called at PLAYER_LOGIN; calling it again does nothing.
function Probe.Start()
  if Probe.frame then
    return Probe.registration
  end
  Probe.frame = CreateFrame("Frame")
  Probe.registration = Platform.RegisterEvents(Probe.frame, Probe.EVENTS)
  Probe.frame:SetScript("OnEvent", onEvent)
  Probe.hooked = Platform.HookSecure("DoEmote", function(...)
    Probe.Record("hook:DoEmote", ...)
  end)
  return Probe.registration
end

-- Reports -------------------------------------------------------------------------------------------------------

-- The lines of /fach debug probe. Never raises.
function Probe.Run()
  local lines = {}
  local ctx = {}
  local _, interfaceBuild = Platform.Invoke("GetBuildInfo")
  local build = interfaceBuild and interfaceBuild[4] or nil
  lines[1] = ("probe version=%s interface=%s"):format(ns.GetVersion and ns.GetVersion() or "dev", describeScalar(build))
  for index, item in ipairs(Probe.ITEMS) do
    local key, value = runItem(item, ctx)
    lines[#lines + 1] = ("%02d %s=%s"):format(index, key, value)
  end
  lines[#lines + 1] = nativeVerdict()
  local registration = Probe.registration
  if registration then
    lines[#lines + 1] = ("events registered=%d refused=%d%s"):format(
      #registration.registered,
      #registration.refused,
      #registration.refused > 0 and (" refused_list=" .. table.concat(registration.refused, ",")) or ""
    )
  else
    lines[#lines + 1] = "events not started (PLAYER_LOGIN has not run)"
  end
  lines[#lines + 1] = "Type /fach debug probe events for the event log."
  local debug = debugTable()
  if debug then
    local saved = {}
    for index = 1, math.min(#lines, MAX_SAVED_LINES) do
      saved[index] = lines[index]
    end
    debug.lastProbe = saved
  end
  return lines
end

-- The lines of /fach debug probe events: one per event, in probe order, then the hook.
function Probe.EventLines()
  local registration = Probe.registration
  if not registration then
    return { "events not started (PLAYER_LOGIN has not run)" }
  end
  local registered = {}
  for _, event in ipairs(registration.registered) do
    registered[event] = true
  end
  local lines =
    { ("events since login (registered=%d refused=%d)"):format(#registration.registered, #registration.refused) }
  for _, event in ipairs(Probe.EVENTS) do
    local entry = Probe.log[event]
    lines[#lines + 1] = ("%s registered=%s count=%d last=%s"):format(
      event,
      registered[event] and "yes" or "no",
      entry and entry.count or 0,
      entry and entry.last or "-"
    )
  end
  local hook = Probe.log["hook:DoEmote"]
  lines[#lines + 1] = ("hook:DoEmote installed=%s count=%d last=%s"):format(
    tostring(Probe.hooked),
    hook and hook.count or 0,
    hook and hook.last or "-"
  )
  return lines
end

-- The lines of /fach debug selftest: every API the addon relies on with OK or missing.
function Probe.SelfTest()
  local lines = {}
  local okCount = 0
  for _, group in ipairs(Platform.REQUIRED_APIS) do
    local found
    for _, path in ipairs(group) do
      if Platform.Has(path) then
        found = path
        break
      end
    end
    if found then
      okCount = okCount + 1
    end
    lines[#lines + 1] = ("%s %s"):format(found and "OK     " or "missing", table.concat(group, " | "))
  end
  local registration = Probe.registration
  if registration then
    lines[#lines + 1] = ("events registered=%d refused=%d"):format(#registration.registered, #registration.refused)
  else
    lines[#lines + 1] = "events not started"
  end
  table.insert(lines, 1, ("selftest %d/%d APIs OK"):format(okCount, #Platform.REQUIRED_APIS))
  return lines
end

-- Starts the event log at PLAYER_LOGIN (not from Init.lua, which stays untouched by this phase).
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
  Probe.Start()
end)

ns.Probe = Probe

local _, ns = ...

-- The achievements screen without frames: the category tree with counts, the filtered rows and the criteria of one
-- achievement, for the character view (the current character) or the account view (account achievements plus, for
-- each character achievement, who earned it first and when).
-- A context is built once per redraw: { catalog, engine, store, tracker, account, guid, mode }.
local VM = ns.ViewModel
local L = ns.L

local Achievements = {}

Achievements.STATUSES = { "all", "completed", "incomplete" }

-- Rows beyond this are cut, so a broad search never builds hundreds of widgets.
Achievements.ROW_LIMIT = 150

function Achievements.Context(app, mode)
  return {
    catalog = app.catalog,
    engine = app.engine,
    store = app.store,
    tracker = app.tracker,
    account = app.account,
    guid = VM.Guid(app),
    mode = mode == "account" and "account" or "character",
  }
end

local function characterEarned(ctx, guid)
  local char = guid and ctx.store:FindCharacter(guid)
  return char and char.earned or {}
end

-- The character that earned a character achievement first (lowest `at`), or nil.
local function firstEarner(ctx, id)
  local bestGuid, bestEntry
  for guid, char in pairs(ctx.store:Characters()) do
    local entry = char.earned and char.earned[id]
    if entry then
      local better = bestEntry == nil
        or (entry.at or 0) < (bestEntry.at or 0)
        or ((entry.at or 0) == (bestEntry.at or 0) and tostring(guid) < tostring(bestGuid))
      if better then
        bestGuid, bestEntry = guid, entry
      end
    end
  end
  return bestGuid, bestEntry
end

-- { earned, entry, by (guid), byName } of one achievement in this view.
local function earnedState(ctx, ach)
  if ach.scope == "account" then
    if ctx.mode ~= "account" then
      return { earned = false }
    end
    local entry = ctx.store:AccountEarned()[ach.id]
    local char = entry and entry.by and ctx.store:FindCharacter(entry.by)
    return { earned = entry ~= nil, entry = entry, by = entry and entry.by, byName = char and char.name }
  end
  if ctx.mode == "account" then
    local guid, entry = firstEarner(ctx, ach.id)
    local char = guid and ctx.store:FindCharacter(guid)
    return { earned = entry ~= nil, entry = entry, by = guid, byName = char and char.name }
  end
  local entry = characterEarned(ctx, ctx.guid)[ach.id]
  return { earned = entry ~= nil, entry = entry, by = ctx.guid }
end
Achievements.EarnedState = earnedState

local function inView(ctx, ach)
  return ctx.mode == "account" or ach.scope ~= "account"
end

local function factionOk(ctx, ach, state)
  if ach.faction == nil or ach.scope == "account" or state.earned then
    return true
  end
  if ctx.mode == "account" then
    local any = false
    for _, char in pairs(ctx.store:Characters()) do
      any = true
      if char.faction == ach.faction then
        return true
      end
    end
    return not any
  end
  local char = ctx.guid and ctx.store:FindCharacter(ctx.guid)
  return char ~= nil and char.faction == ach.faction
end

-- Counted in the totals: right scope and faction, and not hidden unless earned.
local function counted(ctx, ach)
  if not inView(ctx, ach) then
    return false, nil
  end
  local state = earnedState(ctx, ach)
  if not factionOk(ctx, ach, state) then
    return false, state
  end
  return state.earned or not ach.hidden, state
end

-- Shown in the list: counted, and an unearned chain step only once the step before it is earned.
local function visible(ctx, ach)
  local ok, state = counted(ctx, ach)
  if not ok then
    return false, state
  end
  if state.earned or ach.previous == nil then
    return true, state
  end
  local previous = ctx.catalog.Get(ach.previous)
  return previous ~= nil and earnedState(ctx, previous).earned, state
end
Achievements.IsVisible = visible

local function countCategory(ctx, node)
  local earned, total = 0, 0
  for _, ach in ipairs(ctx.catalog.ByCategory(node.id)) do
    local ok, state = counted(ctx, ach)
    if ok then
      total = total + 1
      if state.earned then
        earned = earned + 1
      end
    end
  end
  local children = {}
  for _, child in ipairs(node.children) do
    local built = countCategory(ctx, child)
    if built.total > 0 then
      children[#children + 1] = built
      earned, total = earned + built.earned, total + built.total
    end
  end
  return {
    id = node.id,
    name = L[node.name],
    earned = earned,
    total = total,
    fraction = VM.Fraction(earned, total),
    text = VM.FractionText(earned, total),
    children = children,
  }
end

-- The category tree with earned/total counts; categories with nothing to show are left out.
function Achievements.Tree(ctx)
  local nodes = {}
  for _, root in ipairs(ctx.catalog.Categories()) do
    local node = countCategory(ctx, root)
    if node.total > 0 then
      nodes[#nodes + 1] = node
    end
  end
  return nodes
end

-- Earned/total over the whole catalog in this view.
function Achievements.Totals(ctx)
  local earned, total = 0, 0
  for _, node in ipairs(Achievements.Tree(ctx)) do
    earned, total = earned + node.earned, total + node.total
  end
  return {
    earned = earned,
    total = total,
    fraction = VM.Fraction(earned, total),
    text = VM.FractionText(earned, total),
  }
end

-- Points of the earned achievements. Character view: the current character's. Account view: every character's
-- plus the account achievements. Feats count nothing.
function Achievements.Points(ctx)
  if ctx.mode == "account" then
    local total = ctx.account:TotalPoints()
    for id in pairs(ctx.store:AccountEarned()) do
      local ach = ctx.catalog.Get(id)
      if ach and not ach.feat then
        total = total + (ach.points or 0)
      end
    end
    return total
  end
  return ctx.guid and ctx.account:CharacterPoints(ctx.guid) or 0
end

local function zeroProgress(ach)
  local criteria = {}
  for index, criterion in ipairs(ach.criteria or {}) do
    criteria[index] = {
      type = criterion.type,
      key = criterion.key,
      current = 0,
      required = criterion.value or 1,
      done = false,
      fraction = 0,
    }
  end
  return { earned = false, criteria = criteria, completed = 0, required = #criteria, fraction = 0 }
end

local function safeProgress(ctx, id, guid)
  local ok, progress = pcall(ctx.engine.GetProgress, ctx.engine, id, guid)
  if ok and progress then
    return progress
  end
  return nil
end

-- The progress an unearned achievement shows: the current character's, or in the account view the best one.
local function progressOf(ctx, ach)
  if ctx.mode ~= "account" or ach.scope == "account" then
    return (ctx.guid and safeProgress(ctx, ach.id, ctx.guid)) or zeroProgress(ach)
  end
  local best
  for guid in pairs(ctx.store:Characters()) do
    local progress = safeProgress(ctx, ach.id, guid)
    if progress and (best == nil or progress.fraction > best.fraction) then
      best = progress
    end
  end
  return best or zeroProgress(ach)
end

local function criterionText(ctx, ach, index, criterion)
  local custom = VM.TextOr("ach." .. ach.id .. ".c" .. index, nil)
  if custom then
    return custom
  end
  if criterion.type == "meta" and criterion.key then
    local target = ctx.catalog.Get(criterion.key)
    return target and VM.Name(ctx.catalog, target.id) or tostring(criterion.key)
  end
  return VM.TextOr("crit." .. criterion.type, criterion.type)
end

-- The criteria of one achievement: text, current/required values, done and a 0..1 fraction. An earned achievement
-- shows every criterion done.
function Achievements.Criteria(ctx, id)
  local ach = ctx.catalog.Get(id)
  if not ach then
    return nil
  end
  local state = earnedState(ctx, ach)
  local progress = state.earned and nil or progressOf(ctx, ach)
  local rows = {}
  for index, criterion in ipairs(ach.criteria or {}) do
    local source = progress and progress.criteria[index]
    local required = criterion.value or 1
    local current = source and source.current or required
    local done = state.earned or (source and source.done) or false
    local fraction = state.earned and 1 or (source and source.fraction or 0)
    rows[index] = {
      text = criterionText(ctx, ach, index, criterion),
      type = criterion.type,
      current = current,
      required = required,
      done = done,
      fraction = fraction,
      valueText = VM.FormatValue(criterion.type, math.min(current, required))
        .. " / "
        .. VM.FormatValue(criterion.type, required),
    }
  end
  local completed, needed
  if progress then
    completed, needed = progress.completed, progress.required
  else
    completed, needed = #rows, #rows
  end
  return {
    rows = rows,
    completed = completed,
    required = needed,
    fraction = state.earned and 1 or progress.fraction,
    -- Several criteria with an n-of-m requirement say how many are needed.
    summary = (#rows > 1) and VM.FractionText(completed, needed) or nil,
  }
end

local function buildRow(ctx, ach, state)
  local row = {
    id = ach.id,
    name = VM.Name(ctx.catalog, ach.id),
    desc = VM.Desc(ctx.catalog, ach.id),
    icon = VM.Icon(ach),
    points = ach.points or 0,
    pointsText = VM.PointsText(ach.points, ach.feat),
    feat = ach.feat == true,
    scope = ach.scope,
    category = ach.category,
    earned = state.earned,
    retro = state.entry and state.entry.retro == true or false,
    tracked = ctx.tracker ~= nil and ctx.tracker:IsTracked(ach.id),
    canTrack = not state.earned,
  }
  if state.earned then
    if ctx.mode == "account" and ach.scope ~= "account" then
      row.dateText = VM.EarnedByLabel(state.byName, state.entry)
    elseif ctx.mode == "account" and state.byName then
      row.dateText = VM.EarnedByLabel(state.byName, state.entry)
    else
      row.dateText = VM.DateLabel(state.entry)
    end
    row.fraction = 1
    row.progressText = ""
  else
    row.dateText = ""
    local progress = progressOf(ctx, ach)
    row.fraction = progress.fraction
    if #progress.criteria == 1 then
      local only = progress.criteria[1]
      row.progressText = VM.FormatValue(only.type, math.min(only.current, only.required))
        .. " / "
        .. VM.FormatValue(only.type, only.required)
    else
      row.progressText = VM.FractionText(progress.completed, progress.required)
    end
  end
  return row
end

-- The rows for a filter { category, search, status }. A search looks through the whole catalog (the category is
-- ignored while there is text); the status is "all" | "completed" | "incomplete". Returns the rows and whether more
-- matched than ROW_LIMIT.
function Achievements.Rows(ctx, filter)
  filter = filter or {}
  local needle = VM.Fold(filter.search or ""):match("^%s*(.-)%s*$")
  local source
  if needle == "" and filter.category then
    source = ctx.catalog.ByCategory(filter.category, true)
  else
    source = ctx.catalog.All()
  end
  local rows, seen, truncated = {}, {}, false
  for _, ach in ipairs(source) do
    if not seen[ach.id] and ctx.catalog.Get(ach.id) == ach then
      seen[ach.id] = true
      local ok, state = visible(ctx, ach)
      if ok then
        local status = filter.status
        local pass = status == nil or status == "all" or (status == "completed") == state.earned
        if pass and needle ~= "" then
          local hay = VM.Fold(VM.Name(ctx.catalog, ach.id) .. " " .. VM.Desc(ctx.catalog, ach.id))
          pass = hay:find(needle, 1, true) ~= nil
        end
        if pass then
          if #rows >= Achievements.ROW_LIMIT then
            truncated = true
            break
          end
          rows[#rows + 1] = buildRow(ctx, ach, state)
        end
      end
    end
  end
  return rows, truncated
end

-- One row by id (used by the tracker and the summary), or nil when the id is unknown.
function Achievements.Row(ctx, id)
  local ach = ctx.catalog.Get(id)
  if not ach then
    return nil
  end
  return buildRow(ctx, ach, earnedState(ctx, ach))
end

-- The tracked achievements for the tracker frame: name, progress text and a 0..1 fraction, always for the current
-- character. `ids` is the tracked list (oldest first).
function Achievements.Tracked(ctx, ids)
  local rows = {}
  for _, id in ipairs(ids) do
    local ach = ctx.catalog.Get(id)
    if ach then
      local progress = (ctx.guid and safeProgress(ctx, id, ctx.guid)) or zeroProgress(ach)
      local text
      if #progress.criteria == 1 then
        local only = progress.criteria[1]
        text = VM.FormatValue(only.type, math.min(only.current, only.required))
          .. " / "
          .. VM.FormatValue(only.type, only.required)
      else
        text = VM.FractionText(progress.completed, progress.required)
      end
      rows[#rows + 1] = {
        id = id,
        name = VM.Name(ctx.catalog, id),
        earned = progress.earned == true,
        fraction = progress.fraction,
        progressText = text,
      }
    end
  end
  return rows
end

ns.ViewModelAchievements = Achievements

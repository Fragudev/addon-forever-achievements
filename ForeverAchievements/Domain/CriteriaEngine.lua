local _, ns = ...

-- Turns facts ({ type, key?, value }) into progress and awards what is complete (plan section 6).
--   * Progress lives in the character's `progress`, keyed type[:key]. Each type declares its mode in
--     Catalog.CRITERIA_TYPES: "max" keeps the highest value, "add" increments a counter.
--   * A fact only evaluates the achievements indexed by its type.
--   * `previous` chains: a step is evaluated only once the previous one is earned, so no step is ever skipped;
--     earning a step re-evaluates the next one (AwardService calls Cascade), so stored progress catches up in order.
--   * `meta` criteria are true once the achievement named by `key` is earned; account_* criteria are computed by
--     AccountService. Achievements of the other faction never apply.
-- deps: store, catalog, award, account (optional), bus (optional), guid (function returning the current GUID).
local Engine = {}
Engine.__index = Engine

function Engine.New(deps)
  return setmetatable({
    store = deps.store,
    catalog = deps.catalog,
    award = deps.award,
    account = deps.account,
    bus = deps.bus,
    guid = deps.guid,
  }, Engine)
end

-- "level", or "reputation:72" when the criterion has a key.
function Engine.ProgressKey(criterion)
  if criterion.key ~= nil then
    return criterion.type .. ":" .. tostring(criterion.key)
  end
  return criterion.type
end

-- 0..1 share of `required` reached. A required value of 0 (or less) is already met: never divides by zero.
function Engine.Fraction(current, required)
  if required <= 0 then
    return 1
  end
  if current <= 0 then
    return 0
  end
  return math.min(current / required, 1)
end

local function required(criterion)
  return criterion.value or 1
end

-- How many criteria must be satisfied.
local function needed(ach)
  local total = #ach.criteria
  if type(ach.require) == "number" then
    return math.min(ach.require, total)
  end
  return total
end

function Engine:IsEarned(ach, guid)
  if ach.scope == "account" then
    return self.store:AccountEarned()[ach.id] ~= nil
  end
  return guid ~= nil and self.store:Earned(guid)[ach.id] ~= nil
end

-- True when any known character earned the (character-scope) achievement.
function Engine:EarnedByAnyone(id)
  for _, char in pairs(self.store:Characters()) do
    if char.earned and char.earned[id] then
      return true
    end
  end
  return false
end

-- The current value of one criterion of `owner` for the character `guid`.
function Engine:Current(criterion, guid, owner)
  local def = self.catalog.CRITERIA_TYPES[criterion.type]
  if def.derived == "meta" then
    local target = self.catalog.Get(criterion.key)
    if not target then
      return 0
    end
    local earned
    if owner.scope == "account" and target.scope ~= "account" then
      earned = self:EarnedByAnyone(target.id)
    else
      earned = self:IsEarned(target, guid)
    end
    return earned and 1 or 0
  elseif def.derived == "account" then
    return self.account and self.account:Value(criterion) or 0
  end
  return self.store:Progress(guid)[Engine.ProgressKey(criterion)] or 0
end

-- False for achievements of the other faction (account achievements ignore faction).
function Engine:Applies(ach, guid)
  if ach.scope == "account" or ach.faction == nil then
    return true
  end
  local char = guid and self.store:FindCharacter(guid)
  return char ~= nil and char.faction == ach.faction
end

-- True when the achievement can be shown: right faction, previous step earned, and not hidden unless earned.
function Engine:IsVisible(ach, guid)
  if not self:Applies(ach, guid) then
    return false
  end
  if self:IsEarned(ach, guid) then
    return true
  end
  if ach.hidden then
    return false
  end
  if ach.previous ~= nil then
    local previous = self.catalog.Get(ach.previous)
    return previous ~= nil and self:IsEarned(previous, guid)
  end
  return true
end

local function isComplete(self, ach, guid)
  if #ach.criteria == 0 then
    return false
  end
  local satisfied = 0
  for _, criterion in ipairs(ach.criteria) do
    if self:Current(criterion, guid, ach) >= required(criterion) then
      satisfied = satisfied + 1
    end
  end
  return satisfied >= needed(ach)
end

-- Awards the achievement when it applies, its previous step is earned and its criteria are met.
-- Returns true when it was awarded now.
function Engine:Evaluate(ach, guid)
  if not self:Applies(ach, guid) or self:IsEarned(ach, guid) then
    return false
  end
  if ach.previous ~= nil then
    local previous = self.catalog.Get(ach.previous)
    if not previous or not self:IsEarned(previous, guid) then
      return false
    end
  end
  if self.award:IsRetro() and ach.retroactive == false then
    return false
  end
  if not isComplete(self, ach, guid) then
    return false
  end
  return (self.award:Grant(ach.id)) == true
end

-- Evaluates every achievement that has a criterion of this type. Returns how many were awarded (cascade included).
function Engine:EvaluateType(criterionType)
  local before = self.award:Total()
  local guid = self.guid()
  for _, ach in ipairs(self.catalog.ByType(criterionType)) do
    self:Evaluate(ach, guid)
  end
  return self.award:Total() - before
end

function Engine:EvaluateTypes(types)
  local total = 0
  for _, criterionType in ipairs(types) do
    total = total + self:EvaluateType(criterionType)
  end
  return total
end

-- Applies a fact to the current character and evaluates what it can affect. Returns how many achievements were
-- awarded. Unknown types, derived types and non-numeric values are ignored.
function Engine:Feed(fact)
  local def = self.catalog.CRITERIA_TYPES[fact.type]
  local guid = self.guid()
  if not def or def.derived or type(fact.value) ~= "number" or not guid then
    return 0
  end
  local progress = self.store:Progress(guid)
  local key = Engine.ProgressKey(fact)
  local old = progress[key] or 0
  local new
  if def.mode == "add" then
    new = old + fact.value
  else
    new = math.max(old, fact.value)
  end
  if new ~= old then
    progress[key] = new
    if self.bus then
      self.bus:Publish("progress.changed", { type = fact.type, key = fact.key, value = new, guid = guid })
    end
  end
  -- Evaluated even when the value did not change: the catalog may have gained achievements since.
  return self:EvaluateType(fact.type)
end

-- Called by AwardService after an award: re-evaluates the next chain step, the metas that list it and, for a
-- character achievement that counts for points, the account point totals.
function Engine:Cascade(ach, guid)
  for _, dependent in ipairs(self.catalog.Dependents(ach.id)) do
    self:Evaluate(dependent, guid)
  end
  if ach.scope ~= "account" and not ach.feat and (ach.points or 0) > 0 then
    self:EvaluateType("account_points")
  end
end

-- Progress of one achievement for the UI: per-criterion current/required, how many are done and a 0..1 fraction.
function Engine:GetProgress(id, guid)
  local ach = self.catalog.Get(id)
  if not ach then
    return nil
  end
  guid = guid or self.guid()
  local earned = self:IsEarned(ach, guid)
  local criteria = {}
  local fractions = {}
  local done = 0
  for index, criterion in ipairs(ach.criteria) do
    local current = self:Current(criterion, guid, ach)
    local target = required(criterion)
    local fraction = Engine.Fraction(current, target)
    local met = current >= target
    if met then
      done = done + 1
    end
    criteria[index] = {
      type = criterion.type,
      key = criterion.key,
      current = current,
      required = target,
      done = met,
      fraction = fraction,
    }
    fractions[index] = fraction
  end

  local count = needed(ach)
  local fraction = 0
  if earned then
    fraction = 1
  elseif count > 0 then
    table.sort(fractions, function(a, b)
      return a > b
    end)
    local sum = 0
    for index = 1, count do
      sum = sum + fractions[index]
    end
    fraction = sum / count
  end
  return { id = id, earned = earned, criteria = criteria, completed = done, required = count, fraction = fraction }
end

ns.CriteriaEngine = Engine

local _, ns = ...

-- Account-wide aggregates over every known character, for the account_* criterion types:
--   account_level_count  characters at level >= criterion.key (default 1)   -> compared with criterion.value
--   account_class_set    distinct classes among the characters
--   account_money        sum of the snapshot money
--   account_points       sum of the points of the earned character achievements; feats count 0
-- The numbers come from the Store (character level, class, snapshot, earned), never from the client.
-- deps: store, catalog, engine is bound with Bind.
local Account = {}
Account.__index = Account

Account.TYPES = { "account_level_count", "account_class_set", "account_money", "account_points" }

function Account.New(deps)
  return setmetatable({ store = deps.store, catalog = deps.catalog, engine = nil }, Account)
end

function Account:Bind(engine)
  self.engine = engine
end

-- Points of the character achievements earned by one character; feats and account achievements are not counted.
function Account:CharacterPoints(guid)
  local char = self.store:FindCharacter(guid)
  local total = 0
  if char then
    for id in pairs(char.earned) do
      local ach = self.catalog.Get(id)
      if ach and ach.scope ~= "account" and not ach.feat then
        total = total + (ach.points or 0)
      end
    end
  end
  return total
end

function Account:TotalPoints()
  local total = 0
  for guid in pairs(self.store:Characters()) do
    total = total + self:CharacterPoints(guid)
  end
  return total
end

-- The aggregate that a criterion of an account_* type compares against.
function Account:Value(criterion)
  local kind = criterion.type
  local characters = self.store:Characters()
  if kind == "account_points" then
    return self:TotalPoints()
  end
  local total = 0
  local classes = {}
  for _, char in pairs(characters) do
    if kind == "account_level_count" then
      if (char.level or 0) >= (criterion.key or 1) then
        total = total + 1
      end
    elseif kind == "account_class_set" then
      if char.class and not classes[char.class] then
        classes[char.class] = true
        total = total + 1
      end
    elseif kind == "account_money" then
      total = total + ((char.snapshot and char.snapshot.money) or 0)
    end
  end
  return total
end

-- Re-evaluates every account achievement. Returns how many were awarded.
function Account:Refresh()
  return self.engine:EvaluateTypes(Account.TYPES)
end

-- Stores the latest info and snapshot values of a character ({ money, played, skills, reps }) and re-evaluates the
-- account achievements. Returns how many were awarded.
function Account:Record(guid, info, snapshot)
  local char = self.store:GetCharacter(guid, info)
  if not char then
    return 0
  end
  for key, value in pairs(snapshot or {}) do
    char.snapshot[key] = value
  end
  return self:Refresh()
end

ns.AccountService = Account

local _, ns = ...

-- Owner of ForeverAchievementsDB (plan section 5.3):
--   { schema, characters = { [guid] = { name, class, race, faction, level, lastSeen, snapshot, progress, earned,
--                                       stats } },
--     account = { earned = { [id] = { at, retro, by } } },
--     settings = { toasts, chat, sound, tracked, minimap = { angle } } }
-- The character identity is the GUID; the name is only for display. Migrations are chained by `schema`.
local Store = {}
Store.__index = Store

Store.DEFAULT_SETTINGS = {
  toasts = true,
  chat = true,
  sound = true,
  tracked = {},
  minimap = { angle = 200 },
}

local CHARACTER_INFO = { "name", "class", "race", "faction", "level" }

local function ensureTable(parent, key)
  if type(parent[key]) ~= "table" then
    parent[key] = {}
  end
  return parent[key]
end

local function copy(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for key, inner in pairs(value) do
    result[key] = copy(inner)
  end
  return result
end

-- Fills what is missing (or has the wrong type) without touching valid values.
local function fillDefaults(target, defaults)
  for key, default in pairs(defaults) do
    if type(default) == "table" then
      if type(target[key]) ~= "table" then
        target[key] = copy(default)
      else
        fillDefaults(target[key], default)
      end
    elseif type(target[key]) ~= type(default) then
      target[key] = default
    end
  end
end

-- Each entry upgrades a db to that version; all of them must be idempotent. Exposed so tests can chain extras.
Store.MIGRATIONS = {
  -- v1: first layout (a missing or empty db is version 0).
  [1] = function(db)
    ensureTable(db, "characters")
    ensureTable(ensureTable(db, "account"), "earned")
    fillDefaults(ensureTable(db, "settings"), Store.DEFAULT_SETTINGS)
  end,
}

local function versionOf(db)
  local version = db.schema
  if type(version) == "number" and version >= 0 and version % 1 == 0 then
    return version
  end
  return 0
end

-- Opens (and migrates) the saved variable. `deps.now` is a function returning the current time; `deps.version`
-- overrides the target schema (tests). Returns the store, or nil plus "newer_schema" when the data comes from a
-- newer addon; the raw table is then left untouched so the data survives a downgrade.
function Store.Open(db, deps)
  deps = deps or {}
  local target = deps.version or ns.Constants.SCHEMA_VERSION
  db = type(db) == "table" and db or {}

  local version = versionOf(db)
  if version > target then
    return nil, "newer_schema"
  end
  for step = version + 1, target do
    Store.MIGRATIONS[step](db)
  end
  db.schema = target

  return setmetatable({
    db = db,
    now = deps.now or function()
      return 0
    end,
  }, Store)
end

-- The raw saved table (assign it back to the saved variable if Open had to create it).
function Store:Db()
  return self.db
end

function Store:Characters()
  return self.db.characters
end

function Store:FindCharacter(guid)
  return self.db.characters[guid]
end

-- Returns the character, created on first use. `info` ({ name, class, race, faction, level }) refreshes the
-- display fields and `lastSeen`. A missing or empty guid returns nil.
function Store:GetCharacter(guid, info)
  if type(guid) ~= "string" or guid == "" then
    return nil
  end
  local characters = self.db.characters
  local char = characters[guid]
  if not char then
    char = { lastSeen = self.now() }
    characters[guid] = char
  end
  ensureTable(char, "progress")
  ensureTable(char, "earned")
  ensureTable(char, "stats")
  local snapshot = ensureTable(char, "snapshot")
  fillDefaults(snapshot, { money = 0, played = 0, skills = {}, reps = {} })
  if info then
    for _, field in ipairs(CHARACTER_INFO) do
      if info[field] ~= nil then
        char[field] = info[field]
      end
    end
    char.lastSeen = self.now()
  end
  return char
end

-- Looks a character up by display name (case-insensitive). Names are not unique; the first match wins.
function Store:FindByName(name)
  if type(name) ~= "string" then
    return nil
  end
  local wanted = name:lower()
  for guid, char in pairs(self.db.characters) do
    if type(char.name) == "string" and char.name:lower() == wanted then
      return guid, char
    end
  end
  return nil
end

-- Removes a character and everything it earned. Returns true when it existed.
function Store:Forget(guid)
  if self.db.characters[guid] == nil then
    return false
  end
  self.db.characters[guid] = nil
  return true
end

function Store:Progress(guid)
  return self:GetCharacter(guid).progress
end

function Store:Earned(guid)
  return self:GetCharacter(guid).earned
end

function Store:Stats(guid)
  return self:GetCharacter(guid).stats
end

function Store:Snapshot(guid)
  return self:GetCharacter(guid).snapshot
end

function Store:AccountEarned()
  return self.db.account.earned
end

function Store:Settings()
  return self.db.settings
end

ns.Store = Store

local _, ns = ...

-- Account-wide settings (db.settings), read and written only through these functions so every default lives in
-- one place and a damaged value never raises:
--   toasts, chat, sound  boolean
--   tracked              list of achievement ids (see TrackerService)
--   minimap              { angle = number }
local Settings = {}
Settings.__index = Settings

local function isBoolean(value)
  return type(value) == "boolean"
end

local VALIDATORS = {
  toasts = isBoolean,
  chat = isBoolean,
  sound = isBoolean,
  tracked = function(value)
    return type(value) == "table"
  end,
  minimap = function(value)
    return type(value) == "table" and type(value.angle) == "number"
  end,
}

function Settings.New(store)
  return setmetatable({ store = store }, Settings)
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

-- The stored value, or the default when it is missing or damaged.
function Settings:Get(key)
  local validate = VALIDATORS[key]
  if not validate then
    return nil
  end
  local settings = self.store:Settings()
  if not validate(settings[key]) then
    settings[key] = copy(self.store.DEFAULT_SETTINGS[key])
  end
  return settings[key]
end

-- Returns true, or false plus "unknown" | "invalid".
function Settings:Set(key, value)
  local validate = VALIDATORS[key]
  if not validate then
    return false, "unknown"
  end
  if not validate(value) then
    return false, "invalid"
  end
  self.store:Settings()[key] = value
  return true
end

ns.Settings = Settings

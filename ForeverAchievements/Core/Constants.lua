local addonName, ns = ...

local Constants = {
  ADDON_NAME = addonName,
  -- Version of the saved data layout (ForeverAchievementsDB.schema). Bump it with every migration.
  SCHEMA_VERSION = 1,
}

ns.Constants = Constants

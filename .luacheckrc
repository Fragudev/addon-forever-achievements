std = "lua51"
max_line_length = 120

-- Addon entry files receive (addonName, ns) via varargs and write SavedVariables.
globals = {
  "ForeverAchievementsDB",
  "SLASH_FACH1",
  "SlashCmdList",
}

-- WoW client API used by the addon. Extend as new APIs are adopted.
read_globals = {
  "C_AddOns",
  "GetLocale",
  "CreateFrame",
  "CreateVector2D",
  "hooksecurefunc",
  "issecretvalue",
  -- Native achievement namespace, read by the probe.
  "C_AchievementInfo",
  -- UI kit.
  "UIParent",
  "UISpecialFrames",
  "CreateFont",
  "STANDARD_TEXT_FONT",
  "GameTooltip",
  "GetPhysicalScreenSize",
  "date",
  "Minimap",
  "GetCursorPosition",
  "IsShiftKeyDown",
}

files["tests/"] = {
  std = "+busted",
  globals = { "_G" },
}

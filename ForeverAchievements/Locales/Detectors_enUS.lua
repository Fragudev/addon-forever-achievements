local _, ns = ...

-- Strings of the application boot and its commands (Core/Init.lua, Core/App.lua).
ns.Locale.Register("enUS", {
  ["app.schema_newer"] = "The saved data was written by a newer version of the addon (schema %d). "
    .. "Forever Achievements is disabled to protect it. Update the addon to use it again.",
  ["app.start_failed"] = "could not start: %s",
  ["forget.usage"] = "usage: /fach forget <character name>",
  ["forget.unknown"] = "No known character is named '%s'.",
  ["forget.current"] = "'%s' is the character you are playing; log in with another one to forget it.",
  ["forget.ambiguous"] = "Several known characters are named '%s'. Use one of these ids instead (/fach forget <id>):",
  ["forget.done"] = "Forgot '%s' and its achievements.",
})

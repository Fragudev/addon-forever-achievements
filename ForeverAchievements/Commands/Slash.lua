local _, ns = ...

-- /fach and its subcommands. Later phases add their own with ns.Slash.Register (/fach <name>) and
-- ns.Slash.RegisterDebug (/fach debug <name>); a handler receives the rest of the line after the name.
local Slash = { commands = {}, debugCommands = {} }

local PREFIX = "|cff33ff99Forever Achievements|r"

local function say(text)
  print(PREFIX .. " " .. text)
end

local function printLines(lines)
  for _, line in ipairs(lines) do
    print(line)
  end
end

local function register(list, name, handler, help)
  for _, entry in ipairs(list) do
    if entry.name == name then
      entry.handler, entry.help = handler, help
      return
    end
  end
  list[#list + 1] = { name = name, handler = handler, help = help }
end

local function find(list, name)
  for _, entry in ipairs(list) do
    if entry.name == name then
      return entry
    end
  end
  return nil
end

-- Adds or replaces /fach <name>.
function Slash.Register(name, handler, help)
  register(Slash.commands, name, handler, help)
end

-- Adds or replaces /fach debug <name>.
function Slash.RegisterDebug(name, handler, help)
  register(Slash.debugCommands, name, handler, help)
end

local function splitFirst(text)
  local word, rest = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
  return word:lower(), rest
end

-- A function that handles a bare /fach (the UI toggles its window); it returns true when it did. Without one, a bare
-- /fach prints the version and the help.
function Slash.SetDefault(handler)
  Slash.default = handler
end

local function printHelp()
  say("commands:")
  if Slash.default then
    print("  /fach                  " .. (ns.L and ns.L["ui.cmd.toggle"] or "open or close the window"))
    print("  /fach help             version and this help")
  else
    print("  /fach                  version and this help")
  end
  for _, entry in ipairs(Slash.commands) do
    print("  /fach " .. entry.help)
  end
end

local function printDebugHelp()
  say("debug commands:")
  for _, entry in ipairs(Slash.debugCommands) do
    print("  /fach debug " .. entry.help)
  end
end

local function runEntry(entry, rest)
  local ok, err = pcall(entry.handler, rest)
  if not ok then
    say("error in /fach " .. entry.name .. ": " .. tostring(err))
  end
end

-- Handles one line typed after /fach.
function Slash.Dispatch(message)
  local name, rest = splitFirst(message)
  if name == "" and Slash.default then
    local ok, handled = pcall(Slash.default)
    if ok and handled then
      return
    end
  end
  if name == "" or name == "help" then
    say(ns.GetVersion())
    printHelp()
    return
  end
  local entry = find(Slash.commands, name)
  if entry then
    runEntry(entry, rest)
  else
    say("unknown command '" .. name .. "'.")
    printHelp()
  end
end

Slash.Register("debug", function(rest)
  local name, args = splitFirst(rest)
  local entry = find(Slash.debugCommands, name)
  if entry then
    runEntry(entry, args)
  else
    printDebugHelp()
  end
end, "debug             diagnostics (debug probe | selftest)")

Slash.RegisterDebug("probe", function(args)
  if args == "events" then
    printLines(ns.Probe.EventLines())
  else
    printLines(ns.Probe.Run())
  end
end, "probe [events]   check every client API and event the addon may use")

Slash.RegisterDebug("selftest", function()
  printLines(ns.Probe.SelfTest())
end, "selftest         which client APIs the addon relies on exist")

SLASH_FACH1 = "/fach"
SlashCmdList["FACH"] = Slash.Dispatch

ns.Slash = Slash

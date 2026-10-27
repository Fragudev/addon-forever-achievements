-- The whole UI (kit, tabs, window, toast, tracker, minimap button, controller) built on fake frames over a wired
-- domain. Call env.teardown() in after_each.
local Fake = dofile("tests/support/fake_frames.lua")
local UiHarness = dofile("tests/support/ui_harness.lua")

local Env = {}

Env.FILES = {
  "UI/Kit/Theme.lua",
  "UI/Kit/Pixel.lua",
  "UI/Kit/Util.lua",
  "UI/Kit/Icons.lua",
  "UI/Kit/Core.lua",
  "UI/Kit/Text.lua",
  "UI/Kit/Controls.lua",
  "UI/Kit/Data.lua",
  "UI/Kit/Shell.lua",
  "UI/Tabs/Summary.lua",
  "UI/Tabs/Achievements.lua",
  "UI/Tabs/Statistics.lua",
  "UI/Main.lua",
  "UI/Toast.lua",
  "UI/Tracker.lua",
  "UI/MinimapButton.lua",
  "UI/UI.lua",
}

local GLOBALS = { "Minimap", "IsShiftKeyDown", "GetCursorPosition", "C_Timer", "SOUNDKIT", "PlaySound", "GameTooltip" }

-- Every widget (and nested widget) under `root`, depth first.
function Env.walk(root, visit)
  visit(root)
  for _, item in ipairs(root.items or {}) do
    Env.walk(item.obj, visit)
  end
end

function Env.find_all(root, kind)
  local found = {}
  Env.walk(root, function(node)
    if node.kind == kind then
      found[#found + 1] = node
    end
  end)
  return found
end

-- The text of every Label, Badge, KeyValue... under root, one string.
function Env.text(root)
  local parts = {}
  Env.walk(root, function(node)
    local o = node.opts or {}
    for _, key in ipairs({ "text", "title", "label", "value", "caption", "subtitle", "description", "hint" }) do
      if type(o[key]) == "string" then
        parts[#parts + 1] = o[key]
      end
    end
  end)
  return table.concat(parts, "\n")
end

function Env.Build()
  local frames = Fake.install()
  local saved = {}
  for _, name in ipairs(GLOBALS) do
    saved[name] = _G[name]
  end
  local env = { frames = frames, said = {} }
  local h = UiHarness.Build(Env.FILES)
  env.h = h
  env.ns = h.ns
  h.ns.GetVersion = function()
    return "9.9.9"
  end
  h.app.Say = function(_, text)
    env.said[#env.said + 1] = text
  end
  _G.Minimap = _G.CreateFrame("Frame", "Minimap", _G.UIParent)
  _G.Minimap:SetSize(140, 140)
  _G.IsShiftKeyDown = function()
    return env.shift == true
  end
  _G.GetCursorPosition = function()
    return 0, 0
  end
  _G.C_Timer = nil
  function env.teardown()
    Fake.uninstall()
    for _, name in ipairs(GLOBALS) do
      _G[name] = saved[name]
    end
    _G.Minimap = saved.Minimap
  end
  return env
end

return Env

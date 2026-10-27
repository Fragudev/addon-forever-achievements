local _, ns = ...

-- The toast shown when an achievement is earned: icon, name and points, with a queue for several at once, a fade in
-- and out and an optional sound. Retroactive grants never show one. The animation is a plain function of the elapsed
-- time (Toast.Alpha), so it is tested without a client. `ui` is the controller made by UI.lua.
local Kit = ns.Kit
local L = ns.L
local Theme = Kit.Theme

local Toast = {}
Toast.__index = Toast

Toast.FADE_IN = 0.25
Toast.HOLD = 4
Toast.FADE_OUT = 0.6
Toast.MAX_QUEUE = 8
Toast.WIDTH, Toast.HEIGHT = 330, 66

-- The sound kit entries tried in order; the first one that exists on this client plays.
Toast.SOUND_NAMES = { "UI_EPICLOOT_TOAST", "IG_QUEST_LIST_COMPLETE", "UI_IG_STORE_PURCHASE_DELIVERED" }

function Toast.Duration()
  return Toast.FADE_IN + Toast.HOLD + Toast.FADE_OUT
end

-- Opacity (0..1) `elapsed` seconds after the toast appeared.
function Toast.Alpha(elapsed)
  if elapsed <= 0 then
    return 0
  elseif elapsed < Toast.FADE_IN then
    return elapsed / Toast.FADE_IN
  elseif elapsed < Toast.FADE_IN + Toast.HOLD then
    return 1
  elseif elapsed < Toast.Duration() then
    return 1 - (elapsed - Toast.FADE_IN - Toast.HOLD) / Toast.FADE_OUT
  end
  return 0
end

function Toast.New(ui)
  return setmetatable({ ui = ui, queue = {}, current = nil, elapsed = 0 }, Toast)
end

-- Plays the toast sound when the client has one. Never raises.
function Toast.PlaySound()
  local kit = _G.SOUNDKIT
  if type(kit) ~= "table" or type(_G.PlaySound) ~= "function" then
    return false
  end
  for _, name in ipairs(Toast.SOUND_NAMES) do
    local id = kit[name]
    if type(id) == "number" then
      return (pcall(_G.PlaySound, id))
    end
  end
  return false
end

local function chatLine(info)
  if info.feat or info.points <= 0 then
    return string.format(L["ui.chat.earned_feat"], info.name)
  end
  return string.format(L["ui.chat.earned"], info.name, info.points)
end

-- Handles achievement.earned. Returns true when a toast was queued.
function Toast:OnEarned(event)
  if type(event) ~= "table" or event.retro then
    return false
  end
  local catalog = self.ui.app.catalog
  local settings = self.ui.app.settings
  local ach = event.achievement or catalog.Get(event.id)
  local info = {
    id = event.id,
    name = ns.ViewModel.Name(catalog, event.id),
    points = event.points or (ach and ach.points) or 0,
    feat = event.feat == true,
    icon = ns.ViewModel.Icon(ach),
  }
  if settings:Get("chat") then
    local app = self.ui.app
    if type(app.Say) == "function" then
      app:Say(chatLine(info))
    else
      print("|cff33ff99Forever Achievements|r " .. chatLine(info))
    end
  end
  if not settings:Get("toasts") then
    return false
  end
  local queue = self.queue
  if #queue >= Toast.MAX_QUEUE then
    table.remove(queue, 1)
  end
  queue[#queue + 1] = info
  if not self.current then
    self:Next()
  end
  return true
end

function Toast:Build()
  if self.frame then
    return
  end
  local frame = CreateFrame("Frame", "ForeverAchievementsToast", UIParent)
  frame:SetSize(Toast.WIDTH, Toast.HEIGHT)
  frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:EnableMouse(false)
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetAllPoints(frame)
  frame.bg:SetColorTexture(Theme.Color("panel", 0.96))
  frame.border = Kit.Pixel.Border(frame, "gold")
  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetSize(44, 44)
  frame.icon:SetPoint("LEFT", 12, 0)
  frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  frame.title = frame:CreateFontString(nil, "OVERLAY")
  frame.title:SetFontObject(Theme.StyleFont("label"))
  Kit.SetTextColor(frame.title, "gold")
  frame.title:SetPoint("TOPLEFT", 68, -12)
  frame.title:SetJustifyH("LEFT")
  frame.name = frame:CreateFontString(nil, "OVERLAY")
  frame.name:SetFontObject(Theme.StyleFont("value"))
  Kit.SetTextColor(frame.name, "text")
  frame.name:SetPoint("TOPLEFT", 68, -28)
  frame.name:SetWidth(Toast.WIDTH - 68 - 70)
  frame.name:SetJustifyH("LEFT")
  frame.name:SetWordWrap(false)
  frame.points = frame:CreateFontString(nil, "OVERLAY")
  frame.points:SetFontObject(Theme.StyleFont("hero"))
  Kit.SetTextColor(frame.points, "gold")
  frame.points:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
  frame.points:SetJustifyH("RIGHT")
  frame:Hide()
  self.frame = frame
end

-- Shows the next queued toast, or hides the frame when the queue is empty.
function Toast:Next()
  local info = table.remove(self.queue, 1)
  if not info then
    self.current = nil
    if self.frame then
      self.frame:SetScript("OnUpdate", nil)
      self.frame:Hide()
    end
    return
  end
  self:Build()
  local frame = self.frame
  self.current, self.elapsed = info, 0
  frame.icon:SetTexture(info.icon)
  frame.title:SetText(Kit.Util.Upper(L["ui.toast.title"]))
  frame.name:SetText(info.name)
  frame.points:SetText((info.feat or info.points <= 0) and "" or tostring(info.points))
  frame:SetAlpha(0)
  frame:Show()
  frame:SetScript("OnUpdate", function(_, elapsed)
    self:Tick(elapsed)
  end)
  if self.ui.app.settings:Get("sound") then
    Toast.PlaySound()
  end
end

-- Advances the animation by `dt` seconds.
function Toast:Tick(dt)
  if not self.current then
    return
  end
  self.elapsed = self.elapsed + (tonumber(dt) or 0)
  if self.elapsed >= Toast.Duration() then
    self:Next()
    return
  end
  self.frame:SetAlpha(Toast.Alpha(self.elapsed))
end

function Toast:Pending()
  return #self.queue + (self.current and 1 or 0)
end

ns.Toast = Toast

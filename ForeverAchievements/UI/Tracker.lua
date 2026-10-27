local _, ns = ...

-- The tracker frame: a movable list of the achievements the player pinned (at most TrackerService.MAX), each with its
-- progress. It redraws on progress.changed and achievement.earned (coalesced when the client has timers) and keeps
-- its position in the settings. `ui` is the controller made by UI.lua.
local Kit = ns.Kit
local L = ns.L
local VMA = ns.ViewModelAchievements
local Theme = Kit.Theme

local TrackerFrame = {}
TrackerFrame.__index = TrackerFrame

TrackerFrame.WIDTH = 260
local PAD = { 12, 10, 12, 10 }

function TrackerFrame.New(ui)
  return setmetatable({ ui = ui, pending = false }, TrackerFrame)
end

function TrackerFrame:Build()
  if self.frame then
    return
  end
  local frame = CreateFrame("Frame", "ForeverAchievementsTracker", UIParent)
  frame:SetSize(TrackerFrame.WIDTH, 40)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  local status = self.ui:Status("tracker")
  frame:ClearAllPoints()
  if type(status.left) == "number" and type(status.top) == "number" then
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", status.left, status.top)
  else
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -260)
  end
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetAllPoints(frame)
  frame.bg:SetColorTexture(Theme.Color("panel", 0.9))
  frame.border = Kit.Pixel.Border(frame, "border")
  frame:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    self:SavePosition()
  end)
  frame:Hide()
  self.frame = frame
  self.stack = Kit.Stack(frame, { gap = 6, pad = PAD })
end

function TrackerFrame:SavePosition()
  local left, top = self.frame:GetLeft(), self.frame:GetTop()
  if type(left) == "number" and type(top) == "number" then
    local status = self.ui:Status("tracker")
    status.left, status.top = left, top
  end
end

-- Redraws the frame now; it hides itself when nothing is tracked.
function TrackerFrame:Refresh()
  local app = self.ui.app
  local ids = app.tracker:List()
  if #ids == 0 then
    if self.frame then
      self.frame:Hide()
    end
    return
  end
  self:Build()
  local rows = VMA.Tracked(VMA.Context(app, "character"), ids)
  local stack = self.stack
  stack:Clear()
  Kit.SectionLabel(stack, { text = L["ui.tracker.title"] })
  for _, row in ipairs(rows) do
    local line = Kit.Row(stack, { gap = 8, align = "center", layout = { gap = 8 } })
    Kit.Label(line, { text = row.name, style = "smallMedium", layout = { weight = 1 } })
    Kit.Label(line, { text = row.progressText, style = "small", color = "dim", layout = { width = "auto" } })
    Kit.ProgressBar(stack, { value = row.fraction, height = 4, color = "accent", layout = { gap = 3 } })
  end
  local height = stack:Layout(TrackerFrame.WIDTH)
  Kit.Place(stack, self.frame, 0, 0)
  self.frame:SetSize(TrackerFrame.WIDTH, height)
  self.frame:Show()
end

-- Asks for a redraw: immediate without timers, otherwise at most one per short delay.
function TrackerFrame:Request()
  local timer = _G.C_Timer
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    self:Refresh()
    return
  end
  if self.pending then
    return
  end
  self.pending = true
  timer.After(0.15, function()
    self.pending = false
    self:Refresh()
  end)
end

-- A tracked achievement that was earned leaves the list.
function TrackerFrame:OnEarned(event)
  if type(event) == "table" and event.id then
    self.ui.app.tracker:Untrack(event.id)
  end
  self:Request()
end

ns.TrackerFrame = TrackerFrame

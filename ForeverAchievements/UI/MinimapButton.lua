local _, ns = ...

-- The minimap button: the addon logo (cropped to a circle) inside the usual gold ring, dragged around the edge of the
-- minimap. Left click opens or closes the window. The position and whether it is hidden are saved in
-- settings.minimap ({ angle, hide }). The geometry is plain functions and is tested; New builds the real frame and
-- only does so when the client has a Minimap. `ui` is the controller made by UI.lua.
local L = ns.L

local MinimapButton = {}
MinimapButton.__index = MinimapButton

MinimapButton.DEFAULT_ANGLE = 200
MinimapButton.RADIUS_MARGIN = 5
MinimapButton.LOGO = "Interface\\AddOns\\ForeverAchievements\\Media\\forever_achievements_logo"
MinimapButton.MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- Degrees, kept in [0, 360). Anything that is not a number falls back to the default position.
function MinimapButton.NormalizeAngle(angle)
  if type(angle) ~= "number" or angle ~= angle or angle == math.huge or angle == -math.huge then
    return MinimapButton.DEFAULT_ANGLE
  end
  return angle % 360
end

-- Offset of the button from the minimap centre for an angle (0 = right, 90 = up) on a circle of `radius`.
function MinimapButton.Position(angle, radius)
  local radians = math.rad(MinimapButton.NormalizeAngle(angle))
  return math.cos(radians) * radius, math.sin(radians) * radius
end

-- The angle of the cursor around the minimap centre, in [0, 360).
function MinimapButton.AngleFromCursor(centerX, centerY, cursorX, cursorY)
  local atan2 = math.atan2 or math.atan
  return MinimapButton.NormalizeAngle(math.deg(atan2(cursorY - centerY, cursorX - centerX)))
end

function MinimapButton.New(ui)
  local self = setmetatable({ ui = ui }, MinimapButton)
  self:Create()
  return self
end

-- The saved settings, repaired as needed: the table stored in settings.minimap, so changes to it are saved.
function MinimapButton:Settings()
  local minimap = self.ui.app.settings:Get("minimap")
  minimap.angle = MinimapButton.NormalizeAngle(minimap.angle)
  minimap.hide = minimap.hide == true
  return minimap
end

function MinimapButton:IsHidden()
  return self:Settings().hide
end

function MinimapButton:SetHidden(hidden)
  self:Settings().hide = hidden == true
  self:Refresh()
end

function MinimapButton:Place()
  local button = self.button
  if not button then
    return
  end
  local radius = Minimap:GetWidth() / 2 + MinimapButton.RADIUS_MARGIN
  local x, y = MinimapButton.Position(self:Settings().angle, radius)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- While dragging: follow the cursor around the minimap.
function MinimapButton:Follow()
  local centerX, centerY = Minimap:GetCenter()
  local cursorX, cursorY = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  if type(centerX) ~= "number" or type(scale) ~= "number" or scale <= 0 then
    return
  end
  self:Settings().angle = MinimapButton.AngleFromCursor(centerX, centerY, cursorX / scale, cursorY / scale)
  self:Place()
end

function MinimapButton:ShowTooltip()
  if not GameTooltip then
    return
  end
  GameTooltip:SetOwner(self.button, "ANCHOR_LEFT")
  GameTooltip:AddLine(L["ui.title"])
  GameTooltip:AddLine(L["ui.minimap.left"], 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L["ui.minimap.drag"], 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

-- Builds the button once, in the layout the LibDBIcon-based addons use: a dark disc, the icon, the gold ring on top.
function MinimapButton:Create()
  if self.button or not Minimap then
    return
  end
  local button = CreateFrame("Button", "ForeverAchievementsMinimapButton", Minimap)
  self.button = button
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:SetSize(31, 31)
  button:RegisterForClicks("anyUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(20, 20)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetPoint("TOPLEFT", 7, -5)

  -- The logo is a full-colour square: a circular mask keeps its corners off the ring.
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetTexture(MinimapButton.LOGO)
  icon:SetPoint("CENTER", background, "CENTER", 0, 0)
  if icon.SetMask then
    pcall(icon.SetMask, icon, MinimapButton.MASK)
  end

  local ring = button:CreateTexture(nil, "OVERLAY")
  ring:SetSize(53, 53)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  ring:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "LeftButton" then
      self.ui:Toggle()
    end
  end)
  button:SetScript("OnDragStart", function(frame)
    frame:SetScript("OnUpdate", function()
      self:Follow()
    end)
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  button:SetScript("OnDragStop", function(frame)
    frame:SetScript("OnUpdate", nil)
  end)
  button:SetScript("OnEnter", function()
    self:ShowTooltip()
  end)
  button:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  self:Refresh()
end

function MinimapButton:Refresh()
  if not self.button then
    return
  end
  self:Place()
  if self:Settings().hide then
    self.button:Hide()
  else
    self.button:Show()
  end
end

ns.MinimapButton = MinimapButton

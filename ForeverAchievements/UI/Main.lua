local _, ns = ...

-- The main window: the kit's window shell (header with the Character/Account toggle and the points, sidebar, settings
-- popover) and the page of the selected tab. The tabs live in UI/Tabs and register in ns.Tabs; this file only
-- navigates and paints. `ui` is the controller made by UI.lua: { app, state, Status(name), SetMode(mode),
-- ToggleTrack(id), minimap }. Client only.
local Kit = ns.Kit
local L = ns.L
local VM = ns.ViewModel
local VMA = ns.ViewModelAchievements
local Theme = Kit.Theme

local MainWindow = {}
MainWindow.__index = MainWindow

local SIDEBAR_WIDTH = 200
local PAGE_PAD = { 30, 26, 30, 26 }

MainWindow.TABS = {
  { value = "summary", text = "ui.nav.summary", icon = "home" },
  { value = "achievements", text = "ui.nav.achievements", icon = "trophy" },
  { value = "statistics", text = "ui.nav.statistics", icon = "chart" },
}

function MainWindow.New(ui)
  local self = setmetatable({ ui = ui, contentWidth = 800, contentHeight = 580 }, MainWindow)
  local window = Kit.Window.New({
    name = "ForeverAchievementsWindow",
    title = L["ui.title"],
    version = type(ns.GetVersion) == "function" and ns.GetVersion() or nil,
    buttons = {
      {
        name = "settings",
        icon = "gear",
        tooltip = L["ui.settings"],
        onClick = function()
          self:ToggleSettings()
        end,
      },
    },
    onResize = function(width, height)
      self:OnResize(width, height)
    end,
    onClose = function()
      Kit.CloseAllPopups()
    end,
  })
  self.window = window
  local status = ui:Status("window")
  status.width = type(status.width) == "number" and status.width or Theme.metrics.window.width
  status.height = type(status.height) == "number" and status.height or Theme.metrics.window.height
  window:SetStatusTable(status)

  -- The points and the Character/Account toggle sit in the header, left of the buttons.
  local header = window.header
  self.points = header:CreateFontString(nil, "OVERLAY")
  self.points:SetFontObject(Theme.StyleFont("value"))
  Kit.SetTextColor(self.points, "gold")
  self.points:SetPoint("RIGHT", header, "RIGHT", -(window.rightEdge + 12), 0)
  self.points:SetJustifyH("RIGHT")
  self:BuildToggle()

  self.content = CreateFrame("Frame", nil, window.body)
  self.content:SetPoint("TOPLEFT", window.body, "TOPLEFT", SIDEBAR_WIDTH, 0)
  self.content:SetPoint("BOTTOMRIGHT", window.body, "BOTTOMRIGHT", 0, 0)
  self.page = Kit.ScrollArea(self.content, { gap = Theme.metrics.blockGap, pad = PAGE_PAD })
  Kit.Place(self.page, self.content, 0, 0)
  return self
end

function MainWindow:BuildToggle()
  if self.toggle then
    self.toggle:Release()
  end
  local header = self.window.header
  self.toggle = Kit.Segmented(header, {
    items = {
      { value = "character", text = L["ui.view.character"] },
      { value = "account", text = L["ui.view.account"] },
    },
    value = self.ui.state.mode,
    onChange = function(value)
      self.ui:SetMode(value)
    end,
  })
  self.toggle:Layout(self.toggle:NaturalWidth())
  self.toggle.frame:ClearAllPoints()
  self.toggle.frame:SetPoint("RIGHT", self.points, "LEFT", -18, 0)
end

function MainWindow:IsOpen()
  return self.window:IsShown()
end

function MainWindow:BuildSidebar()
  if self.sidebar then
    self.sidebar:Release()
  end
  local items = {}
  for _, tab in ipairs(MainWindow.TABS) do
    items[#items + 1] = { value = tab.value, text = L[tab.text], icon = tab.icon }
  end
  local card = VM.CharacterCard(self.ui.app, self.ui.state.mode)
  self.sidebar = Kit.Sidebar(self.window.body, {
    groups = { { items = items } },
    value = self.ui.state.tab,
    onSelect = function(value)
      self:SelectTab(value)
    end,
    user = card,
  })
  self.sidebar:Layout(SIDEBAR_WIDTH, self.contentHeight)
  Kit.Place(self.sidebar, self.window.body, 0, 0)
end

function MainWindow:OnResize(width, height)
  self.contentWidth, self.contentHeight = width - SIDEBAR_WIDTH, height
  if self.sidebar then
    self.sidebar:Layout(SIDEBAR_WIDTH, height)
  end
  self:Relayout()
end

function MainWindow:Relayout()
  if self:IsOpen() then
    local offset = self.page:GetScroll()
    self.page:Layout(self.contentWidth, self.contentHeight)
    self.page:SetScroll(offset)
  end
end

function MainWindow:UpdateHeader()
  local ctx = VMA.Context(self.ui.app, self.ui.state.mode)
  self.points:SetText(string.format(L["ui.points"], VM.Thousands(VMA.Points(ctx))))
end

-- Draws the header and the tab again, keeping the scroll position.
function MainWindow:Redraw()
  if not self:IsOpen() then
    return
  end
  local ui = self.ui
  local ctx = VMA.Context(ui.app, ui.state.mode)
  self:UpdateHeader()
  local offset = self.page:GetScroll()
  self.page:Clear()
  local env = {
    app = ui.app,
    mode = ui.state.mode,
    ctx = ctx,
    state = ui.state,
    redraw = function()
      self:Redraw()
    end,
    toggleTrack = function(id)
      ui:ToggleTrack(id)
    end,
  }
  local tab = ns.Tabs and ns.Tabs[ui.state.tab]
  if tab then
    local ok, err = pcall(tab.Draw, self.page, env)
    if not ok then
      -- A failing tab must not take the window down: say so, in the window.
      Kit.Banner(self.page, { kind = "danger", text = tostring(err) })
    end
  end
  self.page:Layout(self.contentWidth, self.contentHeight)
  self.page:SetScroll(offset)
end

function MainWindow:SelectTab(tab)
  local ui = self.ui
  if tab ~= ui.state.tab then
    self.page:SetScroll(0)
  end
  ui.state.tab = tab
  self:BuildSidebar()
  self:Redraw()
end

-- The character/account switch changed: the toggle, sidebar card, header and page follow.
function MainWindow:ModeChanged()
  if not self:IsOpen() then
    return
  end
  self:BuildToggle()
  self:BuildSidebar()
  self:Redraw()
end

local function settingSwitch(stack, ui, key, label)
  Kit.Switch(stack, {
    label = label,
    checked = ui.app.settings:Get(key) == true,
    onChange = function(on)
      ui.app.settings:Set(key, on)
    end,
  })
end

function MainWindow:ToggleSettings()
  local popup = Kit.Popup.Get(1)
  if popup:IsOpen() then
    popup:Close()
    return
  end
  local ui = self.ui
  popup:Open(self.window.buttons.settings.frame, 320, function(stack)
    Kit.SectionLabel(stack, { text = L["ui.settings"] })
    settingSwitch(stack, ui, "toasts", L["ui.settings.toasts"])
    settingSwitch(stack, ui, "sound", L["ui.settings.sound"])
    settingSwitch(stack, ui, "chat", L["ui.settings.chat"])
    Kit.Switch(stack, {
      label = L["ui.settings.minimap"],
      checked = not (ui.minimap and ui.minimap:IsHidden()),
      onChange = function(on)
        if ui.minimap then
          ui.minimap:SetHidden(not on)
        end
      end,
    })
    Kit.Label(stack, { text = L["ui.settings_note"], style = "small", color = "muted", wrap = true })
  end, { point = "BOTTOMRIGHT" })
end

function MainWindow:Show()
  self.window:Show()
  self:BuildToggle()
  self:BuildSidebar()
  self:Redraw()
end

function MainWindow:Hide()
  self.window:Hide()
end

function MainWindow:Toggle()
  if self:IsOpen() then
    self:Hide()
  else
    self:Show()
  end
end

ns.MainWindow = MainWindow

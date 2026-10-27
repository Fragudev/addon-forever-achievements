local _, ns = ...

-- Achievements tab: a category tree on the left, a search box and a status filter on top, and the list of
-- achievements. Clicking a row opens its criteria; Shift-click tracks it. The rows come from ViewModelAchievements.
local Kit = ns.Kit
local L = ns.L
local VM = ns.ViewModel
local VMA = ns.ViewModelAchievements
local Theme = Kit.Theme

ns.Tabs = ns.Tabs or {}

local ROW_HEIGHT = 58
local ICON_SIZE = 38
local RIGHT_WIDTH = 150
local TREE_WIDTH = 230

local function shiftDown()
  return IsShiftKeyDown ~= nil and IsShiftKeyDown() == true
end

-- One achievement: icon, name, description, points, date or progress. opts: row (a ViewModelAchievements row),
-- expanded, onClick(shift).
Kit.Define("AchievementRow", {
  frameType = "Button",
  create = function(obj)
    local frame = obj.frame
    frame:RegisterForClicks("LeftButtonUp")
    obj.wash = frame:CreateTexture(nil, "BACKGROUND")
    obj.wash:SetAllPoints(frame)
    obj.icon = frame:CreateTexture(nil, "ARTWORK")
    obj.icon:SetSize(ICON_SIZE, ICON_SIZE)
    obj.icon:SetPoint("TOPLEFT", 12, -10)
    obj.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    obj.name = frame:CreateFontString(nil, "OVERLAY")
    obj.name:SetJustifyH("LEFT")
    obj.name:SetWordWrap(false)
    obj.desc = frame:CreateFontString(nil, "OVERLAY")
    obj.desc:SetJustifyH("LEFT")
    obj.desc:SetWordWrap(false)
    obj.points = frame:CreateFontString(nil, "OVERLAY")
    obj.points:SetJustifyH("RIGHT")
    obj.points:SetWordWrap(false)
    obj.date = frame:CreateFontString(nil, "OVERLAY")
    obj.date:SetJustifyH("RIGHT")
    obj.date:SetWordWrap(false)
    obj.pin = frame:CreateTexture(nil, "OVERLAY")
    obj.pin:SetSize(14, 14)
    obj.track = frame:CreateTexture(nil, "ARTWORK")
    obj.fill = frame:CreateTexture(nil, "OVERLAY")
    frame:SetScript("OnClick", function()
      if obj.opts and obj.opts.onClick then
        obj.opts.onClick(shiftDown())
      end
    end)
    frame:SetScript("OnEnter", function()
      obj.hovered = true
      obj:refresh()
    end)
    frame:SetScript("OnLeave", function()
      obj.hovered = false
      obj:refresh()
    end)
    function obj:refresh()
      if self.opts.expanded then
        self.wash:SetColorTexture(Theme.Color("selected"))
      elseif self.hovered then
        self.wash:SetColorTexture(Theme.Color("hover"))
      else
        self.wash:SetColorTexture(0, 0, 0, 0)
      end
    end
  end,
  apply = function(obj, opts)
    local row = opts.row
    obj.hovered = false
    obj.icon:SetTexture(row.icon)
    obj.icon:SetVertexColor(1, 1, 1, row.earned and 1 or 0.5)
    obj.name:SetFontObject(Theme.StyleFont("value"))
    Kit.SetTextColor(obj.name, row.feat and "gold" or "text")
    obj.name:SetText(row.name)
    obj.desc:SetFontObject(Theme.StyleFont("small"))
    Kit.SetTextColor(obj.desc, "muted")
    obj.desc:SetText(row.desc)
    obj.points:SetFontObject(Theme.StyleFont("value"))
    Kit.SetTextColor(obj.points, row.earned and "gold" or "dim")
    obj.points:SetText(row.feat and L["ui.feat"] or row.pointsText)
    obj.date:SetFontObject(Theme.StyleFont("small"))
    Kit.SetTextColor(obj.date, row.earned and "success" or "dim")
    obj.date:SetText(row.earned and row.dateText or row.progressText)
    Kit.Icons.Apply(obj.pin, "pin", "accent")
    obj.pin:SetShown(row.tracked == true)
    obj.track:SetColorTexture(Theme.Color("text", 0.08))
    obj.fill:SetColorTexture(Theme.Color("accent"))
    obj:refresh()
  end,
  layout = function(obj, width)
    local row = obj.opts.row
    local textWidth = math.max(0, width - 12 - ICON_SIZE - 12 - RIGHT_WIDTH - 28)
    local left = 12 + ICON_SIZE + 12
    obj.name:ClearAllPoints()
    obj.name:SetPoint("TOPLEFT", obj.frame, "TOPLEFT", left, -10)
    obj.name:SetWidth(textWidth)
    obj.desc:ClearAllPoints()
    obj.desc:SetPoint("TOPLEFT", obj.frame, "TOPLEFT", left, -30)
    obj.desc:SetWidth(textWidth)
    obj.points:ClearAllPoints()
    obj.points:SetPoint("TOPRIGHT", obj.frame, "TOPRIGHT", -16, -10)
    obj.points:SetWidth(RIGHT_WIDTH)
    obj.date:ClearAllPoints()
    obj.date:SetPoint("TOPRIGHT", obj.frame, "TOPRIGHT", -16, -32)
    obj.date:SetWidth(RIGHT_WIDTH)
    obj.pin:ClearAllPoints()
    obj.pin:SetPoint("TOPRIGHT", obj.frame, "TOPRIGHT", -16 - RIGHT_WIDTH, -34)
    obj.pin:SetShown(row.tracked == true)
    -- A thin progress bar under the description of an achievement that is not earned yet.
    obj.track:ClearAllPoints()
    obj.fill:ClearAllPoints()
    if row.earned then
      obj.track:Hide()
      obj.fill:Hide()
    else
      obj.track:SetPoint("TOPLEFT", obj.frame, "TOPLEFT", left, -(ROW_HEIGHT - 9))
      obj.track:SetSize(textWidth, 3)
      obj.track:Show()
      local filled = math.floor(textWidth * VM.Fraction(row.fraction, 1))
      if filled > 0 then
        obj.fill:SetPoint("TOPLEFT", obj.frame, "TOPLEFT", left, -(ROW_HEIGHT - 9))
        obj.fill:SetSize(filled, 3)
        obj.fill:Show()
      else
        obj.fill:Hide()
      end
    end
    return ROW_HEIGHT
  end,
})

-- The category tree as divided rows: the top-level categories, plus the subcategories of the selected one.
local function treeRows(env, tree, totals)
  local state = env.state.ach
  local function select(id)
    return function()
      state.category = id
      env.redraw()
    end
  end
  local rows = {
    {
      title = L["ui.ach.all_categories"],
      value = totals.text,
      selected = state.category == nil,
      onClick = select(nil),
    },
  }
  for _, root in ipairs(tree) do
    local inside = state.category == root.id
    for _, child in ipairs(root.children) do
      inside = inside or state.category == child.id
    end
    rows[#rows + 1] = {
      title = root.name,
      value = root.text,
      selected = state.category == root.id,
      onClick = select(root.id),
    }
    if inside then
      for _, child in ipairs(root.children) do
        rows[#rows + 1] = {
          title = "   " .. child.name,
          value = child.text,
          selected = state.category == child.id,
          onClick = select(child.id),
        }
      end
    end
  end
  return rows
end

local function knownCategory(tree, id)
  for _, root in ipairs(tree) do
    if root.id == id then
      return true
    end
    for _, child in ipairs(root.children) do
      if child.id == id then
        return true
      end
    end
  end
  return false
end

local function criteriaBlock(card, env, row)
  local criteria = VMA.Criteria(env.ctx, row.id)
  if not criteria then
    return
  end
  local stack = Kit.Stack(card, { gap = 8, pad = { 62, 4, 16, 14 } })
  if criteria.summary then
    Kit.Label(stack, {
      text = string.format(L["ui.ach.criteria_summary"], criteria.summary),
      style = "small",
      color = "muted",
    })
  end
  for _, criterion in ipairs(criteria.rows) do
    local line = Kit.Row(stack, { gap = 8, align = "center" })
    Kit.StatusChip(line, { status = criterion.done and "met" or "muted", size = 16, layout = { width = 16 } })
    Kit.Label(line, { text = criterion.text, style = "small", layout = { weight = 1 } })
    Kit.Label(line, { text = criterion.valueText, style = "small", color = "dim", layout = { width = "auto" } })
    if not criterion.done and criterion.required > 1 then
      Kit.ProgressBar(stack, { value = criterion.fraction, height = 4, layout = { gap = 4 } })
    end
  end
end

local function achievementList(list, env, rows)
  local state = env.state.ach
  for _, row in ipairs(rows) do
    local card = Kit.Card(list, { gap = 0, pad = { 0, 0, 0, 0 }, fill = row.earned and "panel" or "side" })
    local expanded = state.expanded[row.id] == true
    Kit.AchievementRow(card, {
      row = row,
      expanded = expanded,
      onClick = function(shift)
        if shift then
          if row.canTrack then
            env.toggleTrack(row.id)
          end
        else
          state.expanded[row.id] = (not expanded) or nil
          env.redraw()
        end
      end,
    })
    if expanded then
      criteriaBlock(card, env, row)
    end
  end
end

ns.Tabs.achievements = {
  Draw = function(page, env)
    local state = env.state.ach
    local tree = VMA.Tree(env.ctx)
    if state.category ~= nil and not knownCategory(tree, state.category) then
      state.category = nil
    end
    Kit.PageHeader(page, { title = L["ui.ach.title"], description = L["ui.ach.desc"] })

    local controls = Kit.Row(page, { gap = 12, align = "center" })
    Kit.EditBox(controls, {
      text = state.search,
      placeholder = L["ui.search_hint"],
      layout = { weight = 1 },
      onCommit = function(text)
        state.search = text
        env.redraw()
      end,
    })
    local statuses = {}
    for _, status in ipairs(VMA.STATUSES) do
      statuses[#statuses + 1] = { value = status, text = L["ui.ach.status." .. status] }
    end
    Kit.Segmented(controls, {
      items = statuses,
      value = state.status,
      layout = { width = "auto" },
      onChange = function(value)
        state.status = value
        env.redraw()
      end,
    })

    local body = Kit.Row(page, { gap = 16 })
    local left = Kit.Stack(body, { gap = 8, layout = { width = TREE_WIDTH } })
    Kit.List(left, { rows = treeRows(env, tree, VMA.Totals(env.ctx)) })
    local right = Kit.Stack(body, { gap = 8, layout = { weight = 1 } })
    local rows, truncated =
      VMA.Rows(env.ctx, { category = state.category, search = state.search, status = state.status })
    if #rows == 0 then
      Kit.EmptyState(right, { icon = "search", title = L["ui.ach.empty_title"], hint = L["ui.ach.empty_hint"] })
    else
      achievementList(right, env, rows)
    end
    if truncated then
      Kit.Label(
        right,
        { text = string.format(L["ui.ach.truncated"], VMA.ROW_LIMIT), style = "small", color = "warning", wrap = true }
      )
    end
    Kit.Label(right, { text = L["ui.ach.hint_track"], style = "small", color = "muted" })
  end,
}

local Env = dofile("tests/support/ui_env.lua")

describe("Main window", function()
  local env, h, ns, ui, window

  before_each(function()
    env = Env.Build()
    h, ns = env.h, env.ns
    h.ns.Locale.Use("enUS")
    h.store:GetCharacter("Player-2", { name = "Warlock", class = "WARLOCK", faction = "Horde", level = 20 })
    h.give("Player-1", "t_level", 100)
    h.give("Player-2", "t_money", 200, true)
    ui = ns.UI.Start(h.app)
    ui:Toggle()
    window = ui.window
  end)

  after_each(function()
    env.teardown()
  end)

  local function page()
    return window.page
  end

  local function banners()
    return Env.find_all(page(), "Banner")
  end

  it("opens with the summary and the character view", function()
    assert.is_true(window:IsOpen())
    assert.are.equal("summary", ui.state.tab)
    assert.are.equal(0, #banners())
    local text = Env.text(page())
    assert.is_truthy(text:find("Latest achievements", 1, true))
    assert.is_truthy(text:find("Test t_level", 1, true))
    assert.are.equal("5 points", window.points.text)
    assert.are.equal(1, #Env.find_all(window.sidebar, "UserCard"))
    assert.are.equal("Hero", window.sidebar.card.opts.name)
    assert.are.equal(3, #Env.find_all(window.sidebar, "NavRow"))
  end)

  it("is closable with Escape and remembers its place", function()
    local found = false
    for _, name in ipairs(_G.UISpecialFrames) do
      found = found or name == "ForeverAchievementsWindow"
    end
    assert.is_true(found)
    window.window.header.scripts.OnDragStop()
    local status = h.store:Settings().ui.window
    assert.are.same({ 100, 700 }, { status.left, status.top })
    assert.are.equal(1000, status.width)
    window:Hide()
    assert.is_false(window:IsOpen())
    window:Toggle()
    assert.is_true(window:IsOpen())
  end)

  it("switches between character and account", function()
    window.toggle.segments[2].frame.scripts.OnClick()
    assert.are.equal("account", ui.state.mode)
    assert.are.equal("Account", window.sidebar.card.opts.name)
    assert.are.equal("2 characters", window.sidebar.card.opts.detail)
    assert.is_truthy(Env.text(page()):find("across the account", 1, true))
    assert.are.equal(0, #banners())
    ui:SetMode("character")
    assert.are.equal("Hero", window.sidebar.card.opts.name)
    ui:SetMode("whatever")
    assert.are.equal("character", ui.state.mode)
  end)

  it("keeps working when the mode changes with the window closed", function()
    window:Hide()
    assert.has_no.errors(function()
      ui:SetMode("account")
      ui:RequestRefresh()
    end)
  end)

  it("draws every tab without errors, in both views and both languages", function()
    for _, locale in ipairs({ "enUS", "esES" }) do
      ns.Locale.Use(locale)
      for _, mode in ipairs({ "character", "account" }) do
        ui.state.mode = mode
        for _, tab in ipairs({ "summary", "achievements", "statistics" }) do
          window:SelectTab(tab)
          assert.are.equal(0, #banners(), locale .. " " .. mode .. " " .. tab)
          assert.are.equal(tab, ui.state.tab)
        end
      end
    end
    ns.Locale.Use("enUS")
    window:SelectTab("nonexistent")
    assert.are.equal(0, #banners())
  end)

  it("shows a banner instead of crashing when a tab fails", function()
    ns.Tabs.broken = {
      Draw = function()
        error("boom")
      end,
    }
    window:SelectTab("broken")
    assert.are.equal(1, #banners())
    ns.Tabs.broken = nil
  end)

  it("relayouts on resize", function()
    window.window.frame.scripts.OnSizeChanged()
    window:OnResize(1200, 700)
    assert.are.equal(1000, window.contentWidth)
    assert.are.equal(700, window.contentHeight)
  end)

  describe("achievements tab", function()
    before_each(function()
      window:SelectTab("achievements")
    end)

    local function rows()
      return Env.find_all(page(), "AchievementRow")
    end

    it("lists the achievements of the first category tree entry", function()
      assert.is_true(#rows() > 5)
      assert.is_truthy(Env.text(page()):find("Showing", 1, true) == nil)
    end)

    it("selects a category from the tree and shows its subcategories", function()
      local tree = Env.find_all(page(), "ListRow")
      local feats
      for _, row in ipairs(tree) do
        if row.opts.title == "Feats of Strength" then
          feats = row
        end
      end
      feats.frame.scripts.OnClick()
      assert.are.equal("feats", ui.state.ach.category)
      assert.are.equal(1, #rows())
      assert.is_true(#Env.find_all(page(), "ListRow") >= 3)
      -- Back to all.
      Env.find_all(page(), "ListRow")[1].frame.scripts.OnClick()
      assert.is_nil(ui.state.ach.category)
      -- A category that no longer exists falls back to all.
      ui.state.ach.category = "gone"
      window:Redraw()
      assert.is_nil(ui.state.ach.category)
    end)

    it("selects a subcategory", function()
      ui.state.ach.category = "general"
      window:Redraw()
      local sub
      for _, row in ipairs(Env.find_all(page(), "ListRow")) do
        if row.opts.title:find("Miscellaneous", 1, true) then
          sub = row
        end
      end
      sub.frame.scripts.OnClick()
      assert.are.equal("general.misc", ui.state.ach.category)
    end)

    it("searches when the text box commits", function()
      local box = Env.find_all(page(), "EditBox")[1]
      box.frame:SetFocus()
      box.frame:SetText("t_level")
      box.frame:ClearFocus()
      assert.are.equal("t_level", ui.state.ach.search)
      assert.are.equal(1, #rows())
      box = Env.find_all(page(), "EditBox")[1]
      box.frame:SetFocus()
      box.frame:SetText("no such thing")
      box.frame:ClearFocus()
      assert.are.equal(0, #rows())
      assert.is_truthy(Env.text(page()):find("No achievements found", 1, true))
    end)

    it("filters by status", function()
      local segmented = Env.find_all(page(), "Segmented")[1]
      segmented.segments[2].frame.scripts.OnClick()
      assert.are.equal("completed", ui.state.ach.status)
      assert.are.equal(1, #rows())
      Env.find_all(page(), "Segmented")[1].segments[3].frame.scripts.OnClick()
      assert.are.equal("incomplete", ui.state.ach.status)
      assert.is_true(#rows() > 5)
    end)

    it("expands a row to show its criteria and collapses it again", function()
      ui.state.ach.search = "t_nofm"
      window:Redraw()
      assert.are.equal(1, #rows())
      rows()[1].frame.scripts.OnClick()
      assert.is_true(ui.state.ach.expanded.t_nofm)
      assert.are.equal(3, #Env.find_all(page(), "StatusChip"))
      assert.is_truthy(Env.text(page()):find("completed", 1, true))
      rows()[1].frame.scripts.OnEnter()
      rows()[1].frame.scripts.OnLeave()
      rows()[1].frame.scripts.OnClick()
      assert.is_nil(ui.state.ach.expanded.t_nofm)
      assert.are.equal(0, #Env.find_all(page(), "StatusChip"))
    end)

    it("shows a progress bar for criteria with a target", function()
      ui.state.ach.search = "t_quest_count"
      window:Redraw()
      rows()[1].frame.scripts.OnClick()
      assert.is_true(#Env.find_all(page(), "ProgressBar") >= 1)
    end)

    it("tracks with Shift-click and ignores earned achievements", function()
      ui.state.ach.search = "t_money"
      window:Redraw()
      env.shift = true
      rows()[1].frame.scripts.OnClick()
      assert.are.same({ "t_money" }, h.tracker:List())
      assert.is_true(rows()[1].opts.row.tracked)
      rows()[1].frame.scripts.OnClick()
      assert.are.same({}, h.tracker:List())
      ui.state.ach.search = "t_level"
      window:Redraw()
      rows()[1].frame.scripts.OnClick()
      assert.are.same({}, h.tracker:List())
      env.shift = false
      -- Without IsShiftKeyDown at all a click just expands.
      _G.IsShiftKeyDown = nil
      rows()[1].frame.scripts.OnClick()
      assert.is_true(ui.state.ach.expanded.t_level)
    end)

    it("says when results were cut", function()
      ns.ViewModelAchievements.ROW_LIMIT = 3
      window:Redraw()
      ns.ViewModelAchievements.ROW_LIMIT = 150
      assert.are.equal(3, #rows())
      assert.is_truthy(Env.text(page()):find("Showing the first 3", 1, true))
    end)
  end)

  describe("settings popover", function()
    it("changes the settings through the switches", function()
      window:ToggleSettings()
      local popup = Env.find_all(ns.Kit.Popup.Get(1).stack, "Switch")
      assert.are.equal(4, #popup)
      popup[1].frame.scripts.OnClick()
      assert.is_false(h.settings:Get("toasts"))
      popup[2].frame.scripts.OnClick()
      assert.is_false(h.settings:Get("sound"))
      popup[3].frame.scripts.OnClick()
      assert.is_false(h.settings:Get("chat"))
      popup[4].frame.scripts.OnClick()
      assert.is_true(h.settings:Get("minimap").hide)
      assert.is_false(ui.minimap.button:IsShown())
      window:ToggleSettings()
      assert.is_false(ns.Kit.Popup.Get(1):IsOpen())
      window.window.buttons.settings.frame.scripts.OnClick()
      assert.is_true(ns.Kit.Popup.Get(1):IsOpen())
    end)
  end)

  describe("live updates", function()
    it("redraws the open window when something is earned, at most once per delay with timers", function()
      local queued = {}
      _G.C_Timer = {
        After = function(_, fn)
          queued[#queued + 1] = fn
        end,
      }
      h.award:Grant("t_money")
      h.award:Grant("t_played")
      -- One timer for the tracker and one for the window, however many grants arrive.
      assert.are.equal(2, #queued)
      for _, run in ipairs(queued) do
        run()
      end
      assert.is_truthy(Env.text(page()):find("Test t_played", 1, true))
      assert.is_false(ui.refreshPending)
      window:Hide()
      h.award:Grant("t_death")
      assert.is_false(ui.refreshPending)
      _G.C_Timer = nil
    end)

    it("redraws immediately without timers and on a retro summary", function()
      h.award:Grant("t_money")
      assert.is_truthy(Env.text(page()):find("Test t_money", 1, true))
      h.bus:Publish("retro.completed", { count = 2, errors = {} })
      assert.are.equal(0, #banners())
    end)
  end)
end)

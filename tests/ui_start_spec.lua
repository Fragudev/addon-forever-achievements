local Env = dofile("tests/support/ui_env.lua")

describe("ns.UI.Start", function()
  local env, h, ns, ui

  before_each(function()
    env = Env.Build()
    h, ns = env.h, env.ns
    h.ns.Locale.Use("enUS")
    h.store:GetCharacter("Player-2", { name = "Warlock", class = "WARLOCK", faction = "Horde", level = 20 })
  end)

  after_each(function()
    env.teardown()
  end)

  local function start()
    ui = ns.UI.Start(h.app)
    return ui
  end

  local function count(event)
    return #(h.bus.handlers[event] or {})
  end

  it("subscribes to the three bus events and nothing else", function()
    local earned, progress, retro = count("achievement.earned"), count("progress.changed"), count("retro.completed")
    start()
    assert.are.equal(earned + 1, count("achievement.earned"))
    assert.are.equal(progress + 1, count("progress.changed"))
    assert.are.equal(retro + 1, count("retro.completed"))
    ui:Stop()
    assert.are.equal(earned, count("achievement.earned"))
    assert.are.equal(progress, count("progress.changed"))
  end)

  it("restarting replaces the old subscriptions", function()
    start()
    local before = count("achievement.earned")
    start()
    assert.are.equal(before, count("achievement.earned"))
  end)

  it("builds nothing heavy until it is needed", function()
    start()
    assert.is_nil(_G.ForeverAchievementsWindow)
    assert.is_nil(_G.ForeverAchievementsToast)
    assert.is_nil(_G.ForeverAchievementsTracker)
    assert.is_false(ns.UI.IsOpen())
    ns.UI.Toggle()
    assert.is_not_nil(_G.ForeverAchievementsWindow)
    assert.is_true(ns.UI.IsOpen())
    ns.UI.Toggle()
    assert.is_false(ns.UI.IsOpen())
  end)

  it("does nothing before Start", function()
    local fresh = Env.Build()
    assert.has_no.errors(function()
      fresh.ns.UI.Toggle()
    end)
    assert.is_false(fresh.ns.UI.IsOpen())
    assert.is_nil(fresh.ns.UI.Controller())
    fresh.teardown()
  end)

  describe("toast", function()
    it("shows one for a normal grant with the name and points", function()
      start()
      h.award:Grant("t_level")
      assert.is_not_nil(_G.ForeverAchievementsToast)
      assert.is_true(_G.ForeverAchievementsToast:IsShown())
      assert.are.equal("Test t_level", _G.ForeverAchievementsToast.name.text)
      assert.are.equal("5", _G.ForeverAchievementsToast.points.text)
      assert.are.equal(134400, _G.ForeverAchievementsToast.icon.texture)
    end)

    it("stays quiet for retroactive grants", function()
      start()
      h.award:Grant("t_level", { retro = true })
      h.award:Silent(function()
        h.award:Grant("t_money")
      end)
      assert.is_nil(_G.ForeverAchievementsToast)
      assert.are.same({}, env.said)
      assert.are.equal(0, ui.toast:Pending())
    end)

    it("respects the toasts setting but still prints the chat line", function()
      start()
      h.settings:Set("toasts", false)
      h.award:Grant("t_level")
      assert.is_nil(_G.ForeverAchievementsToast)
      assert.are.same({ "Achievement earned: Test t_level (5 points)" }, env.said)
      h.settings:Set("chat", false)
      h.award:Grant("t_money")
      assert.are.equal(1, #env.said)
    end)

    it("prints feats without points and falls back to print without app:Say", function()
      h.app.Say = nil
      local printed, real = {}, _G.print
      _G.print = function(...)
        printed[#printed + 1] = table.concat({ ... }, " ")
      end
      start()
      h.award:Grant("t_feat")
      _G.print = real
      assert.is_truthy(printed[1]:find("Achievement earned: Test t_feat", 1, true))
      assert.is_nil(printed[1]:find("points", 1, true))
      assert.are.equal("", _G.ForeverAchievementsToast.points.text)
    end)

    it("queues several, shows them one after another and fades", function()
      start()
      h.award:Grant("t_level")
      h.award:Grant("t_money")
      h.award:Grant("t_played")
      assert.are.equal(3, ui.toast:Pending())
      local frame = _G.ForeverAchievementsToast
      assert.are.equal("Test t_level", frame.name.text)
      ui.toast:Tick(0.125)
      assert.are.equal(0.5, frame.alpha)
      ui.toast:Tick(1)
      assert.are.equal(1, frame.alpha)
      ui.toast:Tick(3.5)
      assert.is_true(frame.alpha < 1)
      ui.toast:Tick(1)
      assert.are.equal("Test t_money", frame.name.text)
      frame.scripts.OnUpdate(frame, 10)
      assert.are.equal("Test t_played", frame.name.text)
      ui.toast:Tick(10)
      assert.is_false(frame:IsShown())
      assert.are.equal(0, ui.toast:Pending())
      assert.has_no.errors(function()
        ui.toast:Tick(1)
      end)
    end)

    it("keeps the queue bounded", function()
      start()
      local ids = { "t_level", "t_money", "t_played", "t_quest_count", "t_death", "t_skill_count", "t_pet_count" }
      ns.Toast.MAX_QUEUE = 2
      for _, id in ipairs(ids) do
        h.award:Grant(id)
      end
      ns.Toast.MAX_QUEUE = 8
      assert.are.equal(3, ui.toast:Pending())
    end)

    it("plays the sound only when it is on and exists", function()
      local played = {}
      _G.PlaySound = function(id)
        played[#played + 1] = id
      end
      _G.SOUNDKIT = { UI_EPICLOOT_TOAST = 77 }
      start()
      h.award:Grant("t_level")
      assert.are.same({ 77 }, played)
      h.settings:Set("sound", false)
      h.award:Grant("t_money")
      ui.toast:Tick(10)
      assert.are.same({ 77 }, played)
      assert.is_false(ns.Toast.PlaySound() and false)
      _G.SOUNDKIT = {}
      assert.is_false(ns.Toast.PlaySound())
      _G.SOUNDKIT = nil
      assert.is_false(ns.Toast.PlaySound())
      _G.SOUNDKIT = { UI_EPICLOOT_TOAST = 1 }
      _G.PlaySound = function()
        error("blocked")
      end
      assert.is_false(ns.Toast.PlaySound())
      _G.PlaySound, _G.SOUNDKIT = nil, nil
    end)

    it("ignores malformed events and has a bounded animation", function()
      start()
      assert.is_false(ui.toast:OnEarned(nil))
      assert.is_false(ui.toast:OnEarned({ retro = true }))
      assert.are.equal(0, ns.Toast.Alpha(0))
      assert.are.equal(0, ns.Toast.Alpha(-1))
      assert.are.equal(0, ns.Toast.Alpha(99))
    end)
  end)

  describe("tracker", function()
    local function labels()
      return Env.text(ui.tracker.stack)
    end

    it("stays hidden with nothing tracked and shows tracked achievements with progress", function()
      start()
      assert.is_nil(_G.ForeverAchievementsTracker)
      h.tracker:Track("t_quest_count")
      ui.tracker:Refresh()
      assert.is_true(_G.ForeverAchievementsTracker:IsShown())
      assert.is_truthy(labels():find("Test t_quest_count", 1, true))
      assert.is_truthy(labels():find("0 / 5", 1, true))
    end)

    it("updates on progress.changed", function()
      start()
      h.tracker:Track("t_quest_count")
      h.feed("quest_count", 3)
      assert.is_truthy(labels():find("3 / 5", 1, true))
    end)

    it("coalesces redraws when the client has timers", function()
      local queued = {}
      _G.C_Timer = {
        After = function(_, fn)
          queued[#queued + 1] = fn
        end,
      }
      start()
      h.tracker:Track("t_quest_count")
      h.feed("quest_count", 1)
      h.feed("quest_count", 2)
      assert.are.equal(1, #queued)
      queued[1]()
      assert.is_truthy(labels():find("2 / 5", 1, true))
      assert.is_false(ui.tracker.pending)
    end)

    it("drops an achievement from the list when it is earned", function()
      start()
      h.tracker:Track("t_quest_count")
      h.tracker:Track("t_level")
      ui.tracker:Refresh()
      h.feed("quest_count", 5)
      assert.are.same({ "t_level" }, h.tracker:List())
      assert.is_truthy(labels():find("Test t_level", 1, true))
      h.tracker:Untrack("t_level")
      ui.tracker:Refresh()
      assert.is_false(_G.ForeverAchievementsTracker:IsShown())
    end)

    it("saves its position when dragged and restores it", function()
      start()
      h.tracker:Track("t_level")
      ui.tracker:Refresh()
      local frame = _G.ForeverAchievementsTracker
      frame.scripts.OnDragStart()
      frame.scripts.OnDragStop()
      assert.are.same({ 100, 700 }, { h.store:Settings().ui.tracker.left, h.store:Settings().ui.tracker.top })
      local second = Env.Build()
      second.h.store:Settings().ui = { tracker = { left = 10, top = 500 } }
      second.h.tracker:Track("t_level")
      second.ns.UI.Start(second.h.app)
      local point = _G.ForeverAchievementsTracker.points[1]
      assert.are.same({ "TOPLEFT", _G.UIParent, "BOTTOMLEFT", 10, 500 }, point)
      second.teardown()
    end)
  end)

  describe("tracking from the UI", function()
    it("tracks, untracks and explains refusals", function()
      start()
      assert.is_true(ui:ToggleTrack("t_level"))
      assert.are.same({ "t_level" }, h.tracker:List())
      assert.is_truthy(env.said[#env.said]:find("Tracking Test t_level", 1, true))
      assert.is_true(ui:ToggleTrack("t_level"))
      assert.is_truthy(env.said[#env.said]:find("No longer tracking", 1, true))
      assert.is_false(ui:ToggleTrack("missing"))
      assert.is_truthy(env.said[#env.said]:find("Unknown achievement", 1, true))
      for _, id in ipairs({ "t_money", "t_played", "t_death", "t_skill_count", "t_pet_count", "t_toy_count" }) do
        h.tracker:Track(id)
      end
      for _, id in ipairs({ "t_quest_count", "t_mount_count", "t_bg_win", "t_bg_played" }) do
        h.tracker:Track(id)
      end
      assert.is_false(ui:ToggleTrack("t_level"))
      assert.is_truthy(env.said[#env.said]:find("tracker is full", 1, true))
    end)
  end)

  describe("slash commands", function()
    local printed, realPrint

    before_each(function()
      printed = {}
      realPrint = _G.print
      _G.print = function(...)
        printed[#printed + 1] = table.concat({ ... }, " ")
      end
      assert(loadfile("ForeverAchievements/Commands/Slash.lua"))("ForeverAchievements", ns)
      start()
    end)

    after_each(function()
      _G.print = realPrint
    end)

    it("toggles the window with a bare /fach and keeps /fach help", function()
      SlashCmdList["FACH"]("")
      assert.is_true(ns.UI.IsOpen())
      SlashCmdList["FACH"]("  ")
      assert.is_false(ns.UI.IsOpen())
      assert.are.same({}, printed)
      SlashCmdList["FACH"]("help")
      assert.is_truthy(table.concat(printed, "\n"):find("9.9.9", 1, true))
      assert.is_truthy(table.concat(printed, "\n"):find("open or close the window", 1, true))
      assert.is_truthy(table.concat(printed, "\n"):find("track <id>", 1, true))
    end)

    it("pins an achievement with /fach track", function()
      SlashCmdList["FACH"]("track t_money")
      assert.are.same({ "t_money" }, h.tracker:List())
      SlashCmdList["FACH"]("track t_money")
      assert.are.same({}, h.tracker:List())
      SlashCmdList["FACH"]("track")
      assert.is_truthy(env.said[#env.said]:find("Usage", 1, true))
      SlashCmdList["FACH"]("track nope")
      assert.is_truthy(env.said[#env.said]:find("Unknown achievement 'nope'", 1, true))
      h.give("Player-1", "t_level", 1)
      SlashCmdList["FACH"]("track t_level")
      assert.is_truthy(env.said[#env.said]:find("already earned", 1, true))
      assert.are.same({}, h.tracker:List())
    end)

    it("falls back to the help when the UI toggle fails", function()
      ns.Slash.SetDefault(function()
        error("boom")
      end)
      SlashCmdList["FACH"]("")
      assert.is_truthy(table.concat(printed, "\n"):find("commands:", 1, true))
    end)
  end)
end)

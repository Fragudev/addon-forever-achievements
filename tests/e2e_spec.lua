-- End to end: the real files, in the exact order of the TOC, over the frame fakes. It exists to catch contract
-- mismatches between Init, the App, the detectors and the UI that the unit specs (which build their own pieces) cannot.
local Fake = dofile("tests/support/fake_frames.lua")

local ADDON = "ForeverAchievements"
local TOC = "ForeverAchievements/ForeverAchievements.toc"
local NONE = {}

-- The files of the TOC, in order. Comment lines (#) and blank lines are skipped; the TOC uses backslashes.
local function tocFiles()
  local files = {}
  for line in io.lines(TOC) do
    line = line:gsub("\r", ""):match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1, 1) ~= "#" then
      files[#files + 1] = line:gsub("\\", "/")
    end
  end
  return files
end

describe("End to end", function()
  local ns, frames, printed, saved, character

  -- Sets a client global and remembers what it replaced.
  local function set(name, value)
    if saved[name] == nil then
      local old = rawget(_G, name)
      saved[name] = old == nil and NONE or old
    end
    _G[name] = value
  end

  -- Fires an event on every frame that registered it, in creation order.
  local function fire(event, ...)
    local fired = 0
    for _, frame in ipairs({ unpack(frames) }) do
      if frame.registered and frame.registered[event] and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, event, ...)
        fired = fired + 1
      end
    end
    return fired
  end

  local function lines()
    return table.concat(printed, "\n")
  end

  local function summaryLines()
    local found = {}
    for _, line in ipairs(printed) do
      if line:find("earned before the addon", 1, true) then
        found[#found + 1] = line
      end
    end
    return found
  end

  -- Loads every file of the TOC into a fresh namespace, like the client does.
  local function loadAddon()
    ns = {}
    for _, file in ipairs(tocFiles()) do
      local chunk = assert(loadfile("ForeverAchievements/" .. file))
      chunk(ADDON, ns)
    end
  end

  local function earned(id)
    return ns.store:Earned(character.guid)[id]
  end

  local function login()
    fire("ADDON_LOADED", ADDON)
    fire("PLAYER_LOGIN")
  end

  before_each(function()
    saved = {}
    printed = {}
    character = { guid = "Player-E2E-1", level = 60, money = 123456 }
    frames = Fake.install()
    local base = _G.CreateFrame
    set("CreateFrame", function(...)
      local frame = base(...)
      frame.registered = {}
      frame.RegisterEvent = function(self, event)
        self.registered[event] = true
      end
      return frame
    end)
    set("print", function(...)
      local parts = {}
      for index = 1, select("#", ...) do
        parts[index] = tostring((select(index, ...)))
      end
      printed[#printed + 1] = table.concat(parts, " ")
    end)
    set("ForeverAchievementsDB", nil)
    set("SlashCmdList", {})
    set("Minimap", _G.CreateFrame("Frame", "Minimap", _G.UIParent))
    set("IsShiftKeyDown", function()
      return false
    end)
    set("GetCursorPosition", function()
      return 0, 0
    end)
    set("UnitGUID", function(unit)
      return unit == "player" and character.guid or nil
    end)
    set("UnitLevel", function()
      return character.level
    end)
    set("GetUnitName", function()
      return "Hero Of Many Words"
    end)
    set("UnitName", function()
      return "Hero"
    end)
    set("UnitClass", function()
      return "Warrior", "WARRIOR", 1
    end)
    set("UnitRace", function()
      return "Human", "Human", 1
    end)
    set("UnitFactionGroup", function()
      return "Alliance", "Alliance"
    end)
    set("GetMoney", function()
      return character.money
    end)
    loadAddon()
    ns.Locale.Use("enUS")
  end)

  after_each(function()
    Fake.uninstall()
    for name, old in pairs(saved) do
      _G[name] = old ~= NONE and old or nil
    end
  end)

  it("loads every file of the TOC, with the detector files after Snapshot and before App", function()
    local files = tocFiles()
    local position = {}
    for index, file in ipairs(files) do
      position[file] = index
    end
    assert.is_true(#files > 50)
    for _, detector in ipairs({ "Encounters", "Battlegrounds", "Deaths", "Emotes", "Items", "LootedMoney" }) do
      local file = "Detectors/" .. detector .. ".lua"
      assert.is_true(position[file] > position["Detectors/Snapshot.lua"], file)
      assert.is_true(position[file] < position["Core/App.lua"], file)
    end
    assert.is_function(ns.AppBuilder.Build)
  end)

  describe("a level 60 character with some money", function()
    before_each(function()
      login()
    end)

    it("builds and starts the app", function()
      assert.is_table(ns.App)
      assert.are.equal(ns.store, ns.App.store)
      assert.are.same({}, ns.App.errors)
      assert.is_nil(ns.disabled)
      assert.are.equal(60, ns.store:FindCharacter(character.guid).level)
      assert.are.equal(123456, ns.store:FindCharacter(character.guid).snapshot.money)
    end)

    it("starts every detector and the lockdown queue", function()
      for _, name in ipairs(ns.AppBuilder.DETECTORS) do
        local detector = ns.App.detectors[name]
        assert.is_not_nil(detector, name)
        assert.is_not_nil(detector.registration, name)
        assert.are.same({}, detector.registration.refused, name)
      end
      assert.is_not_nil(ns.App.queue.registration)
    end)

    it("grants the level chain retroactively, with one summary line and no toast", function()
      for _, id in ipairs({ "level_10", "level_20", "level_30", "level_40", "level_50", "level_60" }) do
        assert.is_true(earned(id).retro, id)
      end
      local summary = summaryLines()
      assert.are.equal(1, #summary)
      local count = 0
      for _ in pairs(ns.store:Earned(character.guid)) do
        count = count + 1
      end
      -- The full catalog also has account achievements that a single level 60 character already meets.
      for _ in pairs(ns.store:AccountEarned()) do
        count = count + 1
      end
      local text = summary[1]:gsub("^|c%x%x%x%x%x%x%x%x.-|r ", "")
      assert.are.equal(string.format(ns.L["retro.summary"], count), text)
      assert.is_nil(_G.ForeverAchievementsToast)
      assert.are.equal(0, ns.UI.Controller().toast:Pending())
      assert.is_nil(lines():find("Achievement earned", 1, true))
    end)

    it("starts the UI: /fach toggles the window", function()
      assert.is_table(ns.UI.Controller())
      assert.are.equal(ns.App, ns.UI.Controller().app)
      assert.is_nil(_G.ForeverAchievementsWindow)
      _G.SlashCmdList.FACH("")
      assert.is_true(ns.UI.IsOpen())
      assert.is_true(_G.ForeverAchievementsWindow:IsShown())
      _G.SlashCmdList.FACH("")
      assert.is_false(ns.UI.IsOpen())
    end)

    it("records the highest level in the statistics from the level fact", function()
      assert.are.equal(60, ns.App.stats:Get("highest_level"))
    end)

    describe("an encounter", function()
      before_each(function()
        set("IsInInstance", function()
          return true, "raid"
        end)
      end)

      it("feeds an encounter fact and bumps the boss statistics", function()
        assert.is_true(fire("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1) >= 1)
        assert.are.equal(1, ns.store:Progress(character.guid)["encounter:1084"])
        assert.are.equal(1, ns.App.stats:Get("bosses_killed"))
        assert.are.equal(1, ns.App.stats:Get("raid_bosses"))
      end)

      it("does not feed a wipe", function()
        fire("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 0)
        assert.is_nil(ns.store:Progress(character.guid)["encounter:1084"])
        assert.are.equal(0, ns.App.stats:Get("bosses_killed"))
      end)

      it("holds a death during the fight until the encounter ends", function()
        local inEncounter = true
        set("IsEncounterInProgress", function()
          return inEncounter
        end)
        fire("PLAYER_DEAD")
        assert.are.equal(0, ns.App.stats:Get("deaths"))
        assert.are.equal(1, ns.App.queue:Pending())
        inEncounter = false
        fire("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 0)
        assert.are.equal(1, ns.App.stats:Get("deaths"))
        assert.are.equal(0, ns.App.queue:Pending())
      end)
    end)
  end)

  describe("a level 9 character", function()
    before_each(function()
      character.level = 9
      login()
    end)

    it("starts without granting anything", function()
      assert.are.equal(0, #summaryLines())
      assert.is_nil(earned("level_10"))
    end)

    it("is granted Level 10 live, with exactly one toast", function()
      local grants = 0
      ns.App.bus:Subscribe("achievement.earned", function()
        grants = grants + 1
      end)
      -- The client still reports the old level while PLAYER_LEVEL_UP fires.
      fire("PLAYER_LEVEL_UP", 10)
      character.level = 10
      assert.is_false(earned("level_10").retro)
      assert.are.equal(1, grants)
      local toast = ns.UI.Controller().toast
      assert.are.equal(1, toast:Pending())
      assert.are.equal("Level 10", _G.ForeverAchievementsToast.name.text)
      assert.is_true(_G.ForeverAchievementsToast:IsShown())
      assert.is_truthy(lines():find("Achievement earned: Level 10", 1, true))
      assert.are.equal(10, ns.App.stats:Get("highest_level"))
    end)
  end)

  describe("data from a newer version", function()
    it("disables the addon cleanly", function()
      local db = { schema = 99, characters = {} }
      _G.ForeverAchievementsDB = db
      login()
      assert.are.equal("newer_schema", ns.disabled)
      assert.is_nil(ns.App)
      assert.is_nil(ns.store)
      assert.is_nil(ns.UI.Controller())
      assert.are.equal(db, _G.ForeverAchievementsDB)
      assert.are.equal(99, db.schema)
      assert.are.same({}, db.characters)
      assert.is_truthy(lines():find("schema 99", 1, true))
      -- The in-memory probe log still listens (it never writes without ns.db); nothing else does, and the data stays
      -- exactly as it was.
      fire("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)
      fire("PLAYER_DEAD")
      fire("PLAYER_LOGOUT")
      assert.are.same({ schema = 99, characters = {} }, db)
    end)
  end)
end)

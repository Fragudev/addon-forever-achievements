local Env = dofile("tests/support/detector_env.lua")
local Loader = dofile("tests/support/loader.lua")

describe("App", function()
  local env, ns, fakeSlash, commands, printed, realPrint

  before_each(function()
    env = Env.Build(Loader.CATALOG_FILES)
    ns = env.ns
    commands = {}
    fakeSlash = {
      Register = function(name, handler, help)
        commands[name] = { handler = handler, help = help }
      end,
    }
    printed = {}
    realPrint = _G.print
    _G.print = function(...)
      printed[#printed + 1] = table.concat({ ... }, " ")
    end
  end)

  after_each(function()
    _G.print = realPrint
    env.close()
    ns.UI = nil
  end)

  local function build(extra)
    local deps = {
      store = env.h.store,
      slash = fakeSlash,
      now = function()
        return env.h.time
      end,
      say = function(message)
        env.said[#env.said + 1] = message
      end,
    }
    for key, value in pairs(extra or {}) do
      deps[key] = value
    end
    return ns.AppBuilder.Build(deps)
  end

  local function level60Client()
    _G.UnitGUID = function()
      return "Player-1"
    end
    _G.UnitLevel = function()
      return 60
    end
    _G.GetUnitName = function()
      return "Hero Of Many Words"
    end
    _G.UnitClass = function()
      return "Warrior", "WARRIOR", 1
    end
    _G.UnitRace = function()
      return "Human", "Human", 1
    end
    _G.UnitFactionGroup = function()
      return "Alliance", "Alliance"
    end
  end

  describe("Build", function()
    it("exposes the fields the UI codes against", function()
      local app = build()
      for _, field in ipairs({
        "store",
        "bus",
        "catalog",
        "engine",
        "award",
        "account",
        "retro",
        "stats",
        "tracker",
        "settings",
        "guid",
      }) do
        assert.is_not_nil(app[field], field)
      end
      assert.are.equal(env.h.store, app.store)
      assert.are.equal(ns.Catalog, app.catalog)
      assert.is_function(app.guid)
    end)

    it("wires the services to each other", function()
      local app = build()
      assert.are.equal(app.engine, app.award.engine)
      assert.are.equal(app.engine, app.account.engine)
      assert.are.equal(app.bus, app.award.bus)
      assert.are.equal(app.award, app.engine.award)
      assert.are.equal(app.account, app.engine.account)
      assert.are.equal(app.store, app.stats.store)
      assert.are.equal(app.settings, app.tracker.settings)
    end)

    it("creates every detector in order, Snapshot last", function()
      local app = build()
      local names = {}
      for index, detector in ipairs(app.detectorList) do
        names[index] = detector.name
        assert.are.equal(detector, app.detectors[detector.name])
      end
      assert.are.same(ns.AppBuilder.DETECTORS, names)
      assert.are.equal("Snapshot", names[#names])
    end)

    it("skips a detector that does not exist", function()
      local app = build({ detectors = { "Nope", "Level" } })
      assert.are.equal(1, #app.detectorList)
    end)

    it("takes the GUID from the client and keeps it", function()
      local guid = "Player-5"
      _G.UnitGUID = function()
        return guid
      end
      local app = ns.AppBuilder.Build({ store = env.h.store, slash = fakeSlash })
      assert.are.equal("Player-5", app.guid())
      guid = "Player-6"
      assert.are.equal("Player-5", app.guid())
    end)

    it("has no GUID until the client gives one", function()
      local app = ns.AppBuilder.Build({ store = env.h.store, slash = fakeSlash })
      assert.is_nil(app.guid())
    end)

    it("stamps awards with the server time, then os.time", function()
      level60Client()
      local app = ns.AppBuilder.Build({ store = env.h.store, slash = fakeSlash })
      _G.GetServerTime = function()
        return 4242
      end
      app.award:Grant("level_10")
      assert.are.equal(4242, env.h.store:Earned("Player-1").level_10.at)
      _G.GetServerTime = nil
      app.award:Grant("level_20")
      assert.is_true(env.h.store:Earned("Player-1").level_20.at > 1000000)
    end)

    it("prints with the addon prefix by default", function()
      local app = ns.AppBuilder.Build({ store = env.h.store, slash = fakeSlash })
      app:Say("hello")
      assert.is_truthy(printed[1]:find("Forever Achievements", 1, true))
      assert.is_truthy(printed[1]:find("hello", 1, true))
    end)

    it("registers /fach forget on ns.Slash when no slash is given", function()
      ns.Slash = fakeSlash
      ns.AppBuilder.Build({ store = env.h.store })
      assert.is_function(commands.forget.handler)
      assert.is_truthy(commands.forget.help:find("forget <name>", 1, true))
    end)
  end)

  describe("Start", function()
    it("grants the level chain retroactively at a level 60 login and prints a single summary", function()
      level60Client()
      local app = build()
      local live = {}
      app.bus:Subscribe("achievement.earned", function(event)
        live[#live + 1] = event.id
      end)
      local granted = app:Start()

      for _, id in ipairs({ "level_10", "level_20", "level_30", "level_40", "level_50", "level_60" }) do
        assert.is_true(env.h.store:Earned("Player-1")[id].retro, id)
      end
      assert.are.same({}, live)
      assert.are.equal(app.award:Total(), granted)
      assert.are.equal(1, #env.said)
      assert.are.equal(string.format(ns.L["retro.summary"], granted), env.said[1])
      assert.are.equal("Hero Of Many Words", env.h.store:FindCharacter("Player-1").name)
      assert.are.same({}, app.errors)
    end)

    it("prints the singular summary for one grant", function()
      level60Client()
      _G.UnitLevel = function()
        return 10
      end
      -- Only the level chain applies to this client: drop the fixture achievements that level 10 also satisfies.
      local app = build()
      for _, id in ipairs({ "t_level", "t_alliance_only", "t_horde_only", "t_hidden" }) do
        app.catalog.Get(id).retroactive = false
      end
      app:Start()
      assert.are.same({ ns.L["retro.summary.one"] }, env.said)
    end)

    it("prints nothing when nothing was granted", function()
      level60Client()
      _G.UnitLevel = function()
        return 1
      end
      local app = build()
      app:Start()
      assert.are.same({}, env.said)
    end)

    it("records the character and starts the detectors", function()
      level60Client()
      local app = build()
      app:Start()
      assert.are.equal(10, #env.frames)
      assert.are.equal(60, env.h.store:FindCharacter("Player-1").level)
      local providers = {}
      for _, provider in ipairs(ns.RetroScan.Providers()) do
        providers[provider.type] = true
      end
      for _, kind in ipairs({
        "level",
        "money",
        "played",
        "quest_count",
        "explore_zone",
        "reputation",
        "skill",
        "mount_count",
        "honor_kills",
      }) do
        assert.is_true(providers[kind], kind)
      end
    end)

    it("hands the app to ns.UI.Start last", function()
      level60Client()
      local app = build()
      local seen
      ns.UI = {
        Start = function(received)
          seen = { app = received, earned = env.h.store:Earned("Player-1").level_60 ~= nil }
        end,
      }
      app:Start()
      assert.are.equal(app, seen.app)
      assert.is_true(seen.earned)
    end)

    it("contains an error raised by ns.UI.Start", function()
      level60Client()
      local app = build()
      ns.UI = {
        Start = function()
          error("ui broke")
        end,
      }
      assert.has_no.errors(function()
        app:Start()
      end)
      assert.are.equal("ui", app.errors[#app.errors].where)
      assert.is_truthy(app.errors[#app.errors].error:find("ui broke", 1, true))
    end)

    it("works without a UI", function()
      local app = build()
      ns.UI = {}
      assert.has_no.errors(function()
        app:Start()
      end)
      ns.UI = nil
      assert.has_no.errors(function()
        app:Start()
      end)
    end)

    it("takes the UI from the deps", function()
      local called = false
      local app = build({
        ui = {
          Start = function()
            called = true
          end,
        },
      })
      app:Start()
      assert.is_true(called)
    end)

    it("keeps going when a step fails", function()
      level60Client()
      local app = build()
      app.account.Record = function()
        error("record broke")
      end
      app.detectors.Money.Start = function()
        error("start broke")
      end
      app:Start()
      local where = {}
      for _, entry in ipairs(app.errors) do
        where[entry.where] = entry.error
      end
      assert.is_truthy(where.snapshot:find("record broke", 1, true))
      assert.is_truthy(where["start:Money"]:find("start broke", 1, true))
      assert.is_not_nil(env.h.store:Earned("Player-1").level_60)
    end)

    it("keeps going when the retro scan fails", function()
      local app = build()
      app.retro.Run = function()
        error("scan broke")
      end
      app:Start()
      assert.are.equal("retro", app.errors[#app.errors].where)
    end)

    it("works without a Snapshot detector", function()
      level60Client()
      local app = build({ detectors = { "Level" } })
      app:Start()
      assert.is_not_nil(env.h.store:Earned("Player-1").level_60)
    end)
  end)

  describe("FeedRetro", function()
    it("grants silently and prints one summary", function()
      level60Client()
      local app = build()
      local count = app:FeedRetro({ { type = "played", value = 7200 } })
      assert.are.equal(1, count)
      assert.are.equal(1, #env.said)
    end)

    it("returns 0 and keeps the error when feeding raises", function()
      local app = build()
      app.engine.Feed = function()
        error("feed broke")
      end
      assert.are.equal(0, app:FeedRetro({ { type = "played", value = 1 } }))
      assert.are.equal("FeedRetro", app.errors[1].where)
      assert.are.same({}, env.said)
    end)
  end)

  describe("/fach forget", function()
    before_each(function()
      build({
        guid = function()
          return "Player-1"
        end,
      })
      env.h.store:GetCharacter("Player-2", { name = "Alt One", class = "MAGE", level = 20 })
      env.h.store:GetCharacter("Player-3", { name = "Twin", class = "ROGUE", level = 20 })
      env.h.store:GetCharacter("Player-4", { name = "Twin", class = "PRIEST", level = 20 })
    end)

    local function forget(text)
      commands.forget.handler(text)
      return env.said[#env.said]
    end

    it("forgets another known character, whatever the case and with a multi-word name", function()
      assert.is_truthy(forget("  alt ONE "):find("Forgot", 1, true))
      assert.is_nil(env.h.store:FindCharacter("Player-2"))
      assert.is_not_nil(env.h.store:FindCharacter("Player-1"))
    end)

    it("refuses to forget the current character", function()
      assert.is_truthy(forget("Hero"):find("playing", 1, true))
      assert.is_not_nil(env.h.store:FindCharacter("Player-1"))
    end)

    it("explains an unknown name", function()
      assert.is_truthy(forget("Nobody"):find("No known character is named 'Nobody'", 1, true))
    end)

    it("explains a missing name", function()
      assert.is_truthy(forget("   "):find("usage", 1, true))
      assert.is_truthy(forget(nil):find("usage", 1, true))
    end)

    it("does not guess between characters with the same name and lists their ids", function()
      assert.is_truthy(forget("Twin"):find("Several known characters", 1, true))
      assert.is_not_nil(env.h.store:FindCharacter("Player-3"))
      assert.is_not_nil(env.h.store:FindCharacter("Player-4"))
      assert.are.same({ "  Player-3", "  Player-4" }, printed)
    end)

    it("accepts the exact id", function()
      assert.is_truthy(forget("Player-4"):find("Forgot", 1, true))
      assert.is_nil(env.h.store:FindCharacter("Player-4"))
      assert.is_not_nil(env.h.store:FindCharacter("Player-3"))
    end)
  end)
end)

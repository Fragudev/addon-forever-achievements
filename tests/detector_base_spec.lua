local Env = dofile("tests/support/detector_env.lua")

describe("Detector base", function()
  local env, Detector, class, det, handled

  before_each(function()
    env = Env.Build()
    Detector = env.ns.Detector
    handled = {}
    class = Detector.Class("Probe1", {
      events = { "EVENT_A", "EVENT_B", "NOISY" },
      throttled = { NOISY = true },
      retroType = "level",
    })
    class.Handle = function(_, event, ...)
      handled[#handled + 1] = { event, ... }
    end
    class.Facts = function()
      return { { type = "level", value = 10 } }
    end
    det = class.New(env.app)
  end)

  after_each(function()
    env.close()
  end)

  describe("Class and defaults", function()
    it("registers the class in ns.Detectors and builds instances over the app", function()
      assert.are.equal(class, env.ns.Detectors.Probe1)
      assert.are.equal(env.app, det.app)
      assert.are.equal(env.ns.Platform, det.platform)
    end)

    it("has harmless defaults", function()
      local plain = Detector.Class("Plain", { retroType = nil }).New(env.app)
      assert.are.same({}, plain:Facts())
      assert.is_nil(plain:SnapshotFields())
      assert.is_nil(plain:Handle("X"))
      plain:UpdateSnapshot({ money = 1 })
      plain:QueueSnapshot({ money = 1 })
    end)
  end)

  describe("Start", function()
    it("registers the events on its own frame and the retro provider", function()
      local registration = det:Start()
      assert.are.same({ "EVENT_A", "EVENT_B", "NOISY" }, registration.registered)
      assert.are.same({}, registration.refused)
      assert.is_true(det.frame.events.EVENT_A)
      local provider
      for _, entry in ipairs(env.ns.RetroScan.Providers()) do
        if entry.type == "level" then
          provider = entry
        end
      end
      assert.are.same({ { type = "level", value = 10 } }, provider.fn())
    end)

    it("is idempotent", function()
      local first = det:Start()
      assert.are.equal(first, det:Start())
      assert.are.equal(1, #env.frames)
    end)

    it("reports the events the client refuses", function()
      env.refuse.EVENT_B = true
      local registration = det:Start()
      assert.are.same({ "EVENT_B" }, registration.refused)
      assert.are.same({ "EVENT_A", "NOISY" }, registration.registered)
    end)

    it("never registers the combat log", function()
      local logger = Detector.Class("Logger", { events = { "COMBAT_LOG_EVENT_UNFILTERED" } }).New(env.app)
      assert.are.same({ "COMBAT_LOG_EVENT_UNFILTERED" }, logger:Start().refused)
    end)

    it("refuses every event when the client gives no frame", function()
      _G.CreateFrame = nil
      local registration = det:Start()
      assert.are.same({ "EVENT_A", "EVENT_B", "NOISY" }, registration.refused)
      assert.is_nil(det.frame)
    end)

    it("runs OnStart and contains its error", function()
      local started = 0
      class.OnStart = function()
        started = started + 1
        error("boom")
      end
      det:Start()
      assert.are.equal(1, started)
      assert.is_truthy(det.lastError:find("boom", 1, true))
    end)
  end)

  describe("events", function()
    it("passes the arguments of an event to Handle", function()
      det:Start()
      env.fire(det, "EVENT_A", 1, 2)
      assert.are.same({ { "EVENT_A", 1, 2 } }, handled)
    end)

    it("contains an error in Handle", function()
      class.Handle = function()
        error("boom")
      end
      det:Start()
      assert.has_no.errors(function()
        env.fire(det, "EVENT_A")
      end)
      assert.is_false(det:Run("EVENT_A"))
      assert.is_truthy(det.lastError:find("boom", 1, true))
    end)

    it("coalesces a throttled event into one run after the delay", function()
      env.useTimer()
      det:Start()
      env.fire(det, "NOISY", 1)
      env.fire(det, "NOISY", 2)
      env.fire(det, "NOISY", 3)
      assert.are.same({}, handled)
      assert.are.equal(1, #env.timers)
      assert.are.equal(Detector.THROTTLE_SECONDS, env.timers[1].seconds)
      assert.are.equal(1, env.flush())
      assert.are.same({ { "NOISY" } }, handled)
      env.fire(det, "NOISY")
      assert.are.equal(1, #env.timers)
    end)

    it("runs a throttled event at once when the client has no timer", function()
      det:Start()
      env.fire(det, "NOISY")
      env.fire(det, "NOISY")
      assert.are.equal(2, #handled)
    end)
  end)

  describe("helpers", function()
    it("Number keeps only readable numbers", function()
      assert.are.equal(5, Detector.Number(5))
      assert.is_nil(Detector.Number("5"))
      assert.is_nil(Detector.Number(0 / 0))
      assert.is_nil(Detector.Number(nil))
      _G.issecretvalue = function(value)
        return value == 7
      end
      assert.is_nil(Detector.Number(7))
    end)

    it("ReferencedKeys lists the keys of one criterion type", function()
      local keys = Detector.ReferencedKeys(env.ns.Catalog, "quest_id")
      assert.is_true(keys[100])
      assert.is_true(keys[1])
      assert.is_nil(keys[999])
      assert.are.same({}, Detector.ReferencedKeys(env.ns.Catalog, "level"))
    end)

    it("Publish feeds the engine and counts the awards", function()
      assert.are.equal(1, det:Publish({ { type = "level", value = 10 } }))
      assert.is_not_nil(env.h.earned("t_level"))
    end)

    it("hands snapshot work to the Snapshot detector when there is one", function()
      local calls = {}
      env.app.detectors.Snapshot = {
        Update = function(_, fields, info)
          calls[#calls + 1] = { "update", fields, info }
        end,
        Queue = function(_, fields)
          calls[#calls + 1] = { "queue", fields }
        end,
      }
      det:UpdateSnapshot({ a = 1 }, { level = 2 })
      det:QueueSnapshot({ b = 2 })
      assert.are.same({ { "update", { a = 1 }, { level = 2 } }, { "queue", { b = 2 } } }, calls)
    end)
  end)
end)

local Loader = dofile("tests/support/loader.lua")

describe("Store", function()
  local ns, Store

  before_each(function()
    ns = Loader.Load({ "Core/Constants.lua", "Core/Store.lua" })
    Store = ns.Store
  end)

  describe("Open and migrations", function()
    it("builds the v1 layout from nothing", function()
      local store = Store.Open(nil)
      local db = store:Db()
      assert.are.equal(ns.Constants.SCHEMA_VERSION, db.schema)
      assert.is_table(db.characters)
      assert.is_table(db.account.earned)
      assert.is_true(db.settings.toasts)
      assert.is_true(db.settings.chat)
      assert.is_true(db.settings.sound)
      assert.are.same({}, db.settings.tracked)
      assert.are.equal(200, db.settings.minimap.angle)
    end)

    it("treats an empty table as version 0 and keeps what it holds", function()
      local raw = { keep = "me" }
      local store = Store.Open(raw)
      assert.are.equal(raw, store:Db())
      assert.are.equal("me", raw.keep)
      assert.are.equal(1, raw.schema)
    end)

    it("recovers from a damaged schema and damaged tables", function()
      local store = Store.Open({ schema = "banana", characters = 5, settings = { toasts = "yes" } })
      assert.are.equal(1, store:Db().schema)
      assert.is_table(store:Characters())
      assert.is_true(store:Settings().toasts)
    end)

    it("is idempotent and keeps valid settings", function()
      local raw = Store.Open({}):Db()
      raw.settings.sound = false
      raw.settings.minimap.angle = 45
      Store.Open(raw)
      assert.is_false(raw.settings.sound)
      assert.are.equal(45, raw.settings.minimap.angle)
    end)

    it("chains migrations from the saved version up to the target", function()
      local ran = {}
      Store.MIGRATIONS[2] = function(db)
        ran[#ran + 1] = 2
        db.v2 = true
      end
      Store.MIGRATIONS[3] = function(db)
        ran[#ran + 1] = 3
        db.v3 = true
      end
      local raw = Store.Open({}):Db()
      ran = {}
      Store.Open(raw, { version = 3 })
      assert.are.same({ 2, 3 }, ran)
      assert.are.equal(3, raw.schema)
      assert.is_true(raw.v2 and raw.v3)
      -- A db already at v3 runs nothing.
      ran = {}
      Store.Open(raw, { version = 3 })
      assert.are.same({}, ran)
    end)

    it("refuses a newer schema and leaves it untouched", function()
      local raw = { schema = 99, characters = { x = 1 } }
      local store, err = Store.Open(raw)
      assert.is_nil(store)
      assert.are.equal("newer_schema", err)
      assert.are.equal(99, raw.schema)
      assert.are.equal(1, raw.characters.x)
    end)
  end)

  describe("characters", function()
    local store, time

    before_each(function()
      time = 100
      store = Store.Open({}, {
        now = function()
          return time
        end,
      })
    end)

    it("creates a character by GUID with the full shape", function()
      local char = store:GetCharacter("Player-1", { name = "Hero Two Words", class = "MAGE", level = 12 })
      assert.are.equal("Hero Two Words", char.name)
      assert.are.equal("MAGE", char.class)
      assert.are.equal(12, char.level)
      assert.are.equal(100, char.lastSeen)
      assert.are.same({}, char.progress)
      assert.are.same({}, char.earned)
      assert.are.same({}, char.stats)
      assert.are.same({ money = 0, played = 0, skills = {}, reps = {} }, char.snapshot)
      assert.are.equal(char, store:FindCharacter("Player-1"))
    end)

    it("returns the same record and refreshes info only when given", function()
      local first = store:GetCharacter("Player-1", { level = 5 })
      time = 200
      assert.are.equal(first, store:GetCharacter("Player-1"))
      assert.are.equal(100, first.lastSeen)
      store:GetCharacter("Player-1", { level = 6 })
      assert.are.equal(6, first.level)
      assert.are.equal(200, first.lastSeen)
    end)

    it("repairs damaged sub-tables of an existing character", function()
      local char = store:GetCharacter("Player-1")
      char.progress = "oops"
      char.snapshot = nil
      store:GetCharacter("Player-1")
      assert.is_table(char.progress)
      assert.are.equal(0, char.snapshot.money)
    end)

    it("rejects a missing or empty GUID", function()
      assert.is_nil(store:GetCharacter(nil))
      assert.is_nil(store:GetCharacter(""))
      assert.is_nil(store:GetCharacter(42))
    end)

    it("finds by name, case-insensitively", function()
      store:GetCharacter("Player-1", { name = "Hero" })
      local guid, char = store:FindByName("hERO")
      assert.are.equal("Player-1", guid)
      assert.are.equal("Hero", char.name)
      assert.is_nil(store:FindByName("Nobody"))
      assert.is_nil(store:FindByName(nil))
    end)

    it("forgets a character and everything it earned", function()
      store:Earned("Player-1").level_10 = { at = 1 }
      assert.is_true(store:Forget("Player-1"))
      assert.is_nil(store:FindCharacter("Player-1"))
      assert.is_false(store:Forget("Player-1"))
    end)

    it("exposes the per-character accessors", function()
      store:Progress("Player-1").level = 7
      store:Earned("Player-1").a = { at = 1 }
      store:Stats("Player-1").deaths = 2
      store:Snapshot("Player-1").money = 50
      local char = store:FindCharacter("Player-1")
      assert.are.equal(7, char.progress.level)
      assert.is_table(char.earned.a)
      assert.are.equal(2, char.stats.deaths)
      assert.are.equal(50, char.snapshot.money)
    end)

    it("exposes the account earned list and the settings", function()
      store:AccountEarned().x = { at = 1, by = "Player-1" }
      assert.are.equal("Player-1", store:Db().account.earned.x.by)
      assert.are.equal(store:Db().settings, store:Settings())
    end)

    it("works without an injected clock", function()
      local plain = Store.Open({})
      assert.are.equal(0, plain:GetCharacter("Player-9").lastSeen)
    end)
  end)
end)

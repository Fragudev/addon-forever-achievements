local Harness = dofile("tests/support/harness.lua")

describe("RetroScan", function()
  local h, scan, completed

  before_each(function()
    h = Harness.Build()
    scan = h.ns.RetroScan.New({
      engine = h.engine,
      award = h.award,
      account = h.account,
      bus = h.bus,
      providers = {},
    })
    completed = nil
    h.bus:Subscribe("retro.completed", function(event)
      completed = event
    end)
  end)

  it("registers providers per type and replaces a repeated one", function()
    local RetroScan = Harness.Build().ns.RetroScan
    local first = function() end
    local second = function() end
    RetroScan.Register("level", first)
    RetroScan.Register("money", first)
    RetroScan.Register("level", second)
    assert.are.equal(2, #RetroScan.Providers())
    assert.are.equal(second, RetroScan.Providers()[1].fn)
  end)

  it("uses the registered providers by default", function()
    local RetroScan = h.ns.RetroScan
    RetroScan.Register("level", function()
      return { { type = "level", value = 10 } }
    end)
    local live = RetroScan.New({ engine = h.engine, award = h.award })
    assert.are.equal(1, live:Run())
  end)

  it("feeds provider facts silently and returns the number of grants", function()
    scan.providers = {
      {
        type = "level",
        fn = function()
          return { { type = "level", value = 10 } }
        end,
      },
      {
        type = "money",
        fn = function()
          return { type = "money", value = 2000 }
        end,
      },
    }
    assert.are.equal(2, scan:Run())
    assert.is_true(h.earned("t_level").retro)
    assert.is_true(h.earned("t_money").retro)
    assert.are.same({}, h.events)
    assert.are.equal(2, completed.count)
  end)

  it("skips a provider that raises and reports it", function()
    scan.providers = {
      {
        type = "skill",
        fn = function()
          error("no api")
        end,
      },
      {
        type = "level",
        fn = function()
          return { { type = "level", value = 10 } }
        end,
      },
      {
        type = "money",
        fn = function()
          return nil
        end,
      },
    }
    assert.are.equal(1, scan:Run())
    assert.are.equal(1, #scan:Errors())
    assert.are.equal("skill", scan:Errors()[1].type)
    assert.is_truthy(scan:Errors()[1].error:find("no api", 1, true))
    assert.are.equal(1, #completed.errors)
  end)

  it("re-evaluates the account achievements", function()
    h.store:GetCharacter("Player-2", { class = "WARRIOR", level = 12 })
    h.store:GetCharacter("Player-3", { class = "PRIEST", level = 15 })
    assert.are.equal(1, scan:Run())
    assert.is_not_nil(h.store:AccountEarned().t_acc_levels)
    assert.is_true(h.store:AccountEarned().t_acc_levels.retro)
  end)

  it("is idempotent", function()
    scan.providers = {
      {
        type = "level",
        fn = function()
          return { { type = "level", value = 10 } }
        end,
      },
    }
    assert.are.equal(1, scan:Run())
    assert.are.equal(0, scan:Run())
  end)

  it("works without account or bus", function()
    local bare = h.ns.RetroScan.New({ engine = h.engine, award = h.award, providers = {} })
    assert.are.equal(0, bare:Run())
  end)

  it("builds the summary message in the active locale", function()
    local ns = h.ns
    assert.are.equal("Granted 3 achievements earned before the addon", ns.RetroScan.Message(3))
    assert.are.equal("Granted 1 achievement earned before the addon", ns.RetroScan.Message(1))
    ns.Locale.Use("esMX")
    assert.are.equal("Se concedieron 3 logros anteriores al addon", ns.RetroScan.Message(3))
    assert.are.equal("Se concedió 1 logro anterior al addon", ns.RetroScan.Message(1))
  end)
end)

-- A wired domain (store, bus, award, account, engine) over the real categories and the test catalog.
local Loader = dofile("tests/support/loader.lua")
local fixture = dofile("tests/fixtures/catalog.lua")

local Harness = {}

function Harness.Build()
  local ns = Loader.Load(Loader.CORE, Loader.DOMAIN, { "Data/Categories.lua", "Data/Statistics.lua" })
  fixture.Install(ns)

  local h = { ns = ns, time = 1000, guid = "Player-1", events = {} }
  local function now()
    return h.time
  end
  local function guid()
    return h.guid
  end

  h.store = ns.Store.Open({}, { now = now })
  h.store:GetCharacter(
    "Player-1",
    { name = "Hero", class = "WARRIOR", race = "Human", faction = "Alliance", level = 1 }
  )
  h.bus = ns.EventBus.New()
  h.bus:Subscribe("achievement.earned", function(event)
    h.events[#h.events + 1] = event
  end)
  h.award = ns.AwardService.New({ store = h.store, catalog = ns.Catalog, bus = h.bus, now = now, guid = guid })
  h.account = ns.AccountService.New({ store = h.store, catalog = ns.Catalog })
  h.engine = ns.CriteriaEngine.New({
    store = h.store,
    catalog = ns.Catalog,
    award = h.award,
    account = h.account,
    bus = h.bus,
    guid = guid,
  })
  h.award:Bind(h.engine)
  h.account:Bind(h.engine)

  function h.feed(factType, value, key)
    return h.engine:Feed({ type = factType, key = key, value = value })
  end
  function h.earned(id)
    return h.store:Earned(h.guid)[id]
  end
  function h.ids()
    local ids = {}
    for index, event in ipairs(h.events) do
      ids[index] = event.id
    end
    return ids
  end
  return h
end

return Harness

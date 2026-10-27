-- A wired domain plus the UI view models, shaped like the `app` that Phase 3 hands to ns.UI.Start.
local Loader = dofile("tests/support/loader.lua")
local Harness = dofile("tests/support/harness.lua")

local UiHarness = {}

UiHarness.VIEW_MODELS = {
  "Locales/UI_enUS.lua",
  "Locales/UI_esES.lua",
  "UI/ViewModel.lua",
  "UI/ViewModelAchievements.lua",
  "UI/ViewModelSummary.lua",
  "UI/ViewModelStatistics.lua",
}

-- `extra` is an optional list of more files (kit, tabs, ...) loaded into the same namespace.
function UiHarness.Build(extra)
  local h = Harness.Build()
  local ns = h.ns
  for _, file in ipairs(UiHarness.VIEW_MODELS) do
    assert(loadfile("ForeverAchievements/" .. file))("ForeverAchievements", ns)
  end
  for _, file in ipairs(extra or {}) do
    assert(loadfile("ForeverAchievements/" .. file))("ForeverAchievements", ns)
  end
  h.settings = ns.Settings.New(h.store)
  h.tracker = ns.TrackerService.New({ settings = h.settings, catalog = ns.Catalog })
  h.stats = ns.StatisticsService.New({
    store = h.store,
    guid = function()
      return h.guid
    end,
  })
  h.app = {
    store = h.store,
    bus = h.bus,
    catalog = ns.Catalog,
    engine = h.engine,
    award = h.award,
    account = h.account,
    stats = h.stats,
    tracker = h.tracker,
    settings = h.settings,
    guid = function()
      return h.guid
    end,
  }
  function h.ctx(mode)
    return ns.ViewModelAchievements.Context(h.app, mode)
  end
  -- Grants an achievement to a character at a time, bypassing the engine (so the cascade does not interfere).
  function h.give(guid, id, at, retro)
    h.store:GetCharacter(guid).earned[id] = { at = at, retro = retro or false }
  end
  return h
end

UiHarness.Loader = Loader
return UiHarness

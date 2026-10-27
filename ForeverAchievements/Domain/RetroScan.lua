local _, ns = ...

-- Retroactive scan at login. Detectors register a provider per criterion type with RetroScan.Register(type, fn);
-- fn returns the current facts ({ type, key?, value }, or one fact) read from the client. Run() feeds them through
-- the engine in silent retro mode and returns how many achievements were granted, for one summary message.
-- A provider that raises is skipped and its error is reported in the retro.completed event.
local RetroScan = {}
RetroScan.__index = RetroScan

local providers = {}

-- Registers (or replaces) the provider of a criterion type.
function RetroScan.Register(criterionType, fn)
  for _, provider in ipairs(providers) do
    if provider.type == criterionType then
      provider.fn = fn
      return
    end
  end
  providers[#providers + 1] = { type = criterionType, fn = fn }
end

function RetroScan.Providers()
  return providers
end

-- deps: engine, award, account (optional), bus (optional), providers (optional override, for tests).
function RetroScan.New(deps)
  return setmetatable({
    engine = deps.engine,
    award = deps.award,
    account = deps.account,
    bus = deps.bus,
    providers = deps.providers,
    errors = {},
  }, RetroScan)
end

function RetroScan:Run()
  local engine = self.engine
  local errors = {}
  local count = self.award:Silent(function()
    for _, provider in ipairs(self.providers or providers) do
      local ok, facts = pcall(provider.fn)
      if not ok then
        errors[#errors + 1] = { type = provider.type, error = tostring(facts) }
      elseif type(facts) == "table" then
        if facts.type then
          facts = { facts }
        end
        for _, fact in ipairs(facts) do
          engine:Feed(fact)
        end
      end
    end
    if self.account then
      self.account:Refresh()
    end
  end)
  self.errors = errors
  if self.bus then
    self.bus:Publish("retro.completed", { count = count, errors = errors })
  end
  return count
end

function RetroScan:Errors()
  return self.errors
end

-- The summary line for the chat ("Granted 3 achievements earned before the addon").
function RetroScan.Message(count)
  local L = ns.L
  if count == 1 then
    return L["retro.summary.one"]
  end
  return string.format(L["retro.summary"], count)
end

ns.RetroScan = RetroScan

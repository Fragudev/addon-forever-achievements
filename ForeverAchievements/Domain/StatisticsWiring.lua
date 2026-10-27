local _, ns = ...

-- Maps the facts that the engine receives onto statistics, so detectors do not touch the statistics themselves.
-- Attach(bus, stats) listens to "fact.fed" (CriteriaEngine) and applies one rule per fact type:
--   death         deaths (+value)
--   level         highest_level (max)
--   encounter     bosses_killed, and dungeon_bosses or raid_bosses by the fact's instanceType ("party" / "raid")
--   bg_played     bg_played and bg_played_<map id>
--   bg_win        bg_won and bg_won_<map id>
--   honor_kills   honorable_kills (max)
--   money_looted  gold_looted (copper)
--   equip_quality epic_equipped (max, only the quality-4 fact)
--   mount_count   mounts (max)
-- A statistic that has no definition is skipped. Retroactive facts go through the same rules; counters only receive
-- types that have no retroactive source, so a login never inflates them.
local Wiring = {}

local function add(stats, id, amount)
  stats:Increment(id, amount)
end

local function raise(stats, id, value)
  stats:SetMax(id, value)
end

-- A counter that also has one entry per map: bg_played, bg_played_489.
local function perMap(prefix)
  return function(stats, fact)
    add(stats, prefix, fact.value)
    if fact.key ~= nil then
      add(stats, prefix .. "_" .. tostring(fact.key), fact.value)
    end
  end
end

Wiring.RULES = {
  death = function(stats, fact)
    add(stats, "deaths", fact.value)
  end,
  level = function(stats, fact)
    raise(stats, "highest_level", fact.value)
  end,
  encounter = function(stats, fact)
    add(stats, "bosses_killed", fact.value)
    if fact.instanceType == "party" then
      add(stats, "dungeon_bosses", fact.value)
    elseif fact.instanceType == "raid" then
      add(stats, "raid_bosses", fact.value)
    end
  end,
  bg_played = perMap("bg_played"),
  bg_win = perMap("bg_won"),
  honor_kills = function(stats, fact)
    raise(stats, "honorable_kills", fact.value)
  end,
  money_looted = function(stats, fact)
    add(stats, "gold_looted", fact.value)
  end,
  equip_quality = function(stats, fact)
    if fact.key == 4 then
      raise(stats, "epic_equipped", fact.value)
    end
  end,
  mount_count = function(stats, fact)
    raise(stats, "mounts", fact.value)
  end,
}

-- Applies one fact. Never raises: a statistic must not stop the engine.
function Wiring.Apply(stats, fact)
  local rule = type(fact) == "table" and Wiring.RULES[fact.type]
  if rule and type(fact.value) == "number" then
    pcall(rule, stats, fact)
  end
end

-- Subscribes to the bus; returns the handler (the token for bus:Unsubscribe).
function Wiring.Attach(bus, stats)
  return bus:Subscribe("fact.fed", function(fact)
    Wiring.Apply(stats, fact)
  end)
end

ns.StatisticsWiring = Wiring

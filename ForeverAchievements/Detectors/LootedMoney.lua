local _, ns = ...

-- Money looted by the player. Facts: money_looted (value = copper of one loot message). Source (assumed, not
-- measured): CHAT_MSG_MONEY, whose text is parsed with patterns built from the localized client globals YOU_LOOT_MONEY
-- and LOOT_MONEY_SPLIT (the player's own loot and share of a split) and GOLD_AMOUNT, SILVER_AMOUNT and COPPER_AMOUNT
-- (the coins inside it). Messages about other players' loot do not match. A secret, non-string or unparseable text,
-- or a client without those globals, publishes nothing. There is no retroactive answer.
local Detector = ns.Detector
local LootedMoney = Detector.Class("LootedMoney", { events = { "CHAT_MSG_MONEY" } })

-- Turns a client format ("You loot %s", "%d Gold") into an anchored pattern with one capture per %s or %d. Gives nil
-- for something that is not a format with a capture, or that uses positional arguments (%1$s), which this parser does
-- not follow.
function LootedMoney.ToPattern(format)
  if type(format) ~= "string" or format:find("%%%d%$") then
    return nil
  end
  local escaped = format:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  escaped = escaped:gsub("%%%%s", function()
    return "(.+)"
  end)
  escaped = escaped:gsub("%%%%d", function()
    return "([%d%.,]+)"
  end)
  if not escaped:find("(", 1, true) then
    return nil
  end
  return "^" .. escaped .. "$"
end

-- The digits of "1,234" or "1.234" as a number.
local function digits(text)
  return tonumber((text:gsub("%D", ""))) or 0
end

-- The patterns, rebuilt until every global is there: { own = { ... }, gold, silver, copper }.
function LootedMoney:Patterns()
  if self.patterns then
    return self.patterns
  end
  local platform = self.platform
  local own = {}
  for _, name in ipairs({ "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT" }) do
    local pattern = LootedMoney.ToPattern(platform.GetGlobalString(name))
    if pattern then
      own[#own + 1] = pattern
    end
  end
  local gold = LootedMoney.ToPattern(platform.GetGlobalString("GOLD_AMOUNT"))
  local silver = LootedMoney.ToPattern(platform.GetGlobalString("SILVER_AMOUNT"))
  local copper = LootedMoney.ToPattern(platform.GetGlobalString("COPPER_AMOUNT"))
  if #own == 0 or not (gold and silver and copper) then
    return nil
  end
  -- The coin patterns sit inside a longer text, so they are not anchored.
  local function loose(pattern)
    return (pattern:gsub("^%^", ""):gsub("%$$", ""))
  end
  self.patterns = { own = own, gold = loose(gold), silver = loose(silver), copper = loose(copper) }
  return self.patterns
end

-- Copper in a loot message of the player, or nil when the text is not one.
function LootedMoney:Parse(text)
  if type(text) ~= "string" or self.platform.IsSecret(text) then
    return nil
  end
  local patterns = self:Patterns()
  if not patterns then
    return nil
  end
  local coins
  for _, pattern in ipairs(patterns.own) do
    coins = text:match(pattern)
    if coins then
      break
    end
  end
  if not coins then
    return nil
  end
  local gold, silver, copper = coins:match(patterns.gold), coins:match(patterns.silver), coins:match(patterns.copper)
  local total = (gold and digits(gold) or 0) * 10000 + (silver and digits(silver) or 0) * 100
  total = total + (copper and digits(copper) or 0)
  if total <= 0 then
    return nil
  end
  return total
end

function LootedMoney:Handle(_, text)
  local copper = self:Parse(text)
  if copper then
    self:Publish({ { type = "money_looted", value = copper } })
  end
end

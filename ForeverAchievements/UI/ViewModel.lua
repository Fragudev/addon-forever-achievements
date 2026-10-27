local _, ns = ...

-- Shared presentation helpers: plain functions that turn domain values into the text the windows show. No frames,
-- no client calls except the date function, so everything here is unit tested.
local ViewModel = {}

local L = ns.L

-- The client exposes `date`; tests fall back to os.date. Replaceable so a spec can fix the clock.
ViewModel.dateFn = function(format, stamp)
  local fn = _G.date or (os and os.date)
  return fn(format, stamp)
end

-- 05/11/26 style date (dd/mm/yy). Anything that is not a timestamp gives "".
function ViewModel.FormatDate(stamp)
  if type(stamp) ~= "number" or stamp < 0 then
    return ""
  end
  local ok, text = pcall(ViewModel.dateFn, "%d/%m/%y", stamp)
  if ok and type(text) == "string" then
    return text
  end
  return ""
end

-- "Earned before the addon" for a retro grant, the date otherwise, "" without an entry.
function ViewModel.DateLabel(entry)
  if type(entry) ~= "table" then
    return ""
  end
  if entry.retro then
    return L["ui.earned_before_addon"]
  end
  return ViewModel.FormatDate(entry.at)
end

-- "Earned by Hero on 05/11/26" / "Earned by Hero before the addon".
function ViewModel.EarnedByLabel(name, entry)
  name = name or L["ui.unknown_character"]
  if type(entry) == "table" and entry.retro then
    return string.format(L["ui.earned_by_retro"], name)
  end
  return string.format(L["ui.earned_by"], name, ViewModel.FormatDate(entry and entry.at))
end

-- Points shown on a row; a feat of strength has none.
function ViewModel.PointsText(points, feat)
  if feat or type(points) ~= "number" or points <= 0 then
    return ""
  end
  return tostring(points)
end

-- 0..1 share of `done` in `total`. Never divides by zero: an empty total is 0 (nothing to complete).
function ViewModel.Fraction(done, total)
  if type(done) ~= "number" or type(total) ~= "number" or total <= 0 or done <= 0 then
    return 0
  end
  return math.min(done / total, 1)
end

function ViewModel.FractionText(done, total)
  return string.format("%d/%d", done or 0, total or 0)
end

-- 1234567 -> "1,234,567".
function ViewModel.Thousands(value)
  local text = string.format("%d", math.floor((tonumber(value) or 0) + 0.5))
  local sign, digits = text:match("^(-?)(%d+)$")
  digits = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  return sign .. digits
end

-- Copper -> "12g 5s 3c" (zero parts are left out; 0 is "0c").
function ViewModel.Money(copper)
  copper = math.floor(tonumber(copper) or 0)
  local gold, silver, rest = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
  local parts = {}
  if gold > 0 then
    parts[#parts + 1] = ViewModel.Thousands(gold) .. "g"
  end
  if silver > 0 then
    parts[#parts + 1] = silver .. "s"
  end
  if rest > 0 or #parts == 0 then
    parts[#parts + 1] = rest .. "c"
  end
  return table.concat(parts, " ")
end

-- Seconds -> "3d 4h" / "2h 5m" / "45m" (at least a minute).
function ViewModel.Duration(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  local days, hours, minutes =
    math.floor(seconds / 86400), math.floor((seconds % 86400) / 3600), math.floor((seconds % 3600) / 60)
  if days > 0 then
    return string.format("%dd %dh", days, hours)
  elseif hours > 0 then
    return string.format("%dh %dm", hours, minutes)
  end
  return string.format("%dm", minutes)
end

-- A criterion value in the unit of its type.
function ViewModel.FormatValue(criterionType, value)
  if criterionType == "money" or criterionType == "money_looted" or criterionType == "account_money" then
    return ViewModel.Money(value)
  elseif criterionType == "played" then
    return ViewModel.Duration(value)
  end
  return ViewModel.Thousands(value)
end

-- Lower case without accents, for the search box ("Exploración" matches "exploracion"). The client lower-cases
-- ASCII only, so the accented letters are mapped by hand, both cases.
local FOLD = {
  { "áàâäãÁÀÂÄÃ", "a" },
  { "éèêëÉÈÊË", "e" },
  { "íìîïÍÌÎÏ", "i" },
  { "óòôöõÓÒÔÖÕ", "o" },
  { "úùûüÚÙÛÜ", "u" },
  { "ñÑ", "n" },
  { "çÇ", "c" },
}
local foldMap = {}
for _, entry in ipairs(FOLD) do
  for char in entry[1]:gmatch("[\194-\244][\128-\191]*") do
    foldMap[char] = entry[2]
  end
end

function ViewModel.Fold(text)
  text = tostring(text or "")
  text = text:gsub("[\194-\244][\128-\191]*", function(char)
    return foldMap[char]
  end)
  return text:lower()
end

-- The text of a locale key, or `fallback` when no locale has it (ns.L alone would answer with the key).
function ViewModel.TextOr(key, fallback)
  local current = ns.Locale.Get(ns.Locale.Current())[key]
  if current == nil then
    current = ns.Locale.Get(ns.Locale.DEFAULT)[key]
  end
  if current == nil then
    return fallback
  end
  return current
end

-- The game icon of an achievement, with the question mark as fallback.
ViewModel.FALLBACK_ICON = 134400

function ViewModel.Icon(ach)
  return (ach and ach.icon) or ViewModel.FALLBACK_ICON
end

function ViewModel.Name(catalog, id)
  return L[catalog.NameKey(id)]
end

function ViewModel.Desc(catalog, id)
  return L[catalog.DescKey(id)]
end

-- The current character's GUID: apps hand either the string or the function that returns it.
function ViewModel.Guid(app)
  local guid = app and app.guid
  if type(guid) == "function" then
    guid = guid()
  end
  return type(guid) == "string" and guid ~= "" and guid or nil
end

-- The card at the bottom of the sidebar: { name, detail }. Account view: how many characters are known.
function ViewModel.CharacterCard(app, mode)
  local characters = app.store:Characters()
  if mode == "account" then
    local count = 0
    for _ in pairs(characters) do
      count = count + 1
    end
    return { name = L["ui.view.account"], detail = string.format(L["ui.card.characters"], count) }
  end
  local char = ViewModel.Guid(app) and characters[ViewModel.Guid(app)]
  if not char then
    return { name = L["ui.no_character_name"], detail = "" }
  end
  local classNames = _G.LOCALIZED_CLASS_NAMES_MALE
  local class = char.class and ((classNames and classNames[char.class]) or char.class) or ""
  local detail = class
  if type(char.level) == "number" then
    detail = string.format(L["ui.card.level"], char.level, class)
  end
  return { name = char.name or L["ui.unknown_character"], detail = detail }
end

ns.ViewModel = ViewModel

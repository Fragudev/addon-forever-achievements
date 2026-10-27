local _, ns = ...

-- The achievement catalog. Data/*.lua files register definitions (plan section 5.1) with Catalog.Register and the
-- category tree with Catalog.RegisterCategories; this module indexes them and validates them (plan section 7).
local Catalog = {}

-- The closed set of criterion types (plan section 5.2). Adding a type means adding its detector and tests too.
--   mode    "max" keeps the highest value seen; "add" adds each fact to a counter.
--   derived "meta" is true once the achievement named by `key` is earned; "account" is computed from all the
--           characters by AccountService and never stored as progress.
Catalog.CRITERIA_TYPES = {
  level = { mode = "max" },
  money = { mode = "max" },
  money_looted = { mode = "add" },
  played = { mode = "max" },
  quest_count = { mode = "max" },
  quest_id = { mode = "max" },
  zone_quests = { mode = "max" },
  explore_area = { mode = "max" },
  explore_zone = { mode = "max" },
  reputation = { mode = "max" },
  reputation_count = { mode = "max" },
  skill = { mode = "max" },
  skill_count = { mode = "max" },
  mount_count = { mode = "max" },
  pet_count = { mode = "max" },
  toy_count = { mode = "max" },
  encounter = { mode = "add" },
  honor_kills = { mode = "max" },
  pvp_rank = { mode = "max" },
  bg_win = { mode = "add" },
  bg_played = { mode = "add" },
  death = { mode = "add" },
  emote_target = { mode = "add" },
  item_obtained = { mode = "max" },
  equip_quality = { mode = "max" },
  meta = { derived = "meta" },
  account_level_count = { derived = "account" },
  account_class_set = { derived = "account" },
  account_money = { derived = "account" },
  account_points = { derived = "account" },
}

local POINTS = { [0] = true, [5] = true, [10] = true, [15] = true, [20] = true, [25] = true, [50] = true }
local SCOPES = { character = true, account = true }
local FACTIONS = { Alliance = true, Horde = true }
local LOCALES = { "enUS", "esES" }

local list = {}
local categoryList = {}
local categoryById = {}
local roots = {}
local index

function Catalog.Reset()
  list = {}
  categoryList = {}
  categoryById = {}
  roots = {}
  index = nil
end

-- Adds a list of achievement definitions. Duplicates are kept so Validate can report them; Get returns the first.
function Catalog.Register(definitions)
  for _, definition in ipairs(definitions) do
    list[#list + 1] = definition
  end
  index = nil
end

local function addCategory(node, parent)
  local category = { id = node.id, name = node.name, parent = parent, children = {} }
  categoryList[#categoryList + 1] = category
  categoryById[node.id] = categoryById[node.id] or category
  for _, child in ipairs(node.children or {}) do
    category.children[#category.children + 1] = addCategory(child, node.id)
  end
  return category
end

-- Adds a tree of { id, name, children } nodes; `name` is a locale key.
function Catalog.RegisterCategories(tree)
  for _, node in ipairs(tree) do
    roots[#roots + 1] = addCategory(node, nil)
  end
end

function Catalog.NameKey(id)
  return "ach." .. id .. ".name"
end

function Catalog.DescKey(id)
  return "ach." .. id .. ".desc"
end

local function push(map, key, value)
  local bucket = map[key]
  if not bucket then
    bucket = {}
    map[key] = bucket
  end
  bucket[#bucket + 1] = value
end

local function build()
  if index then
    return index
  end
  index = { byId = {}, byType = {}, byCategory = {}, dependents = {} }
  for _, ach in ipairs(list) do
    if type(ach.id) == "string" and index.byId[ach.id] == nil then
      index.byId[ach.id] = ach
      push(index.byCategory, ach.category, ach)
      local seen = {}
      for _, criterion in ipairs(ach.criteria or {}) do
        if not seen[criterion.type] then
          seen[criterion.type] = true
          push(index.byType, criterion.type, ach)
        end
        if criterion.type == "meta" and criterion.key ~= nil then
          push(index.dependents, criterion.key, ach)
        end
      end
      if ach.previous ~= nil then
        push(index.dependents, ach.previous, ach)
      end
    end
  end
  return index
end

local EMPTY = {}

function Catalog.All()
  return list
end

function Catalog.Get(id)
  return build().byId[id]
end

-- Achievements that have a criterion of this type.
function Catalog.ByType(criterionType)
  return build().byType[criterionType] or EMPTY
end

-- Achievements of a category; with `deep`, also those of its subcategories.
function Catalog.ByCategory(categoryId, deep)
  local own = build().byCategory[categoryId] or EMPTY
  local category = categoryById[categoryId]
  if not deep or not category or #category.children == 0 then
    return own
  end
  local result = { unpack(own) }
  for _, child in ipairs(category.children) do
    for _, ach in ipairs(Catalog.ByCategory(child.id, true)) do
      result[#result + 1] = ach
    end
  end
  return result
end

-- Achievements that depend on this one: the next step of its chain and the metas that list it.
function Catalog.Dependents(id)
  return build().dependents[id] or EMPTY
end

function Catalog.Categories()
  return roots
end

function Catalog.GetCategory(id)
  return categoryById[id]
end

function Catalog.Count()
  return #list
end

local function isBlank(text)
  return type(text) ~= "string" or text == ""
end

-- Finds a dependency cycle through `previous` and meta criteria; reports each node that closes one.
local function findCycles(byId, add)
  local state = {}
  local function visit(id)
    state[id] = "open"
    local ach = byId[id]
    local targets = {}
    if ach.previous ~= nil then
      targets[#targets + 1] = ach.previous
    end
    for _, criterion in ipairs(ach.criteria or {}) do
      if criterion.type == "meta" and criterion.key ~= nil then
        targets[#targets + 1] = criterion.key
      end
    end
    for _, target in ipairs(targets) do
      if byId[target] then
        if state[target] == "open" then
          add("cycle", id, "dependency cycle through " .. target)
        elseif state[target] == nil then
          visit(target)
        end
      end
    end
    state[id] = "done"
  end
  for id in pairs(byId) do
    if state[id] == nil then
      visit(id)
    end
  end
end

-- Checks every rule of plan section 7. Returns a list of { rule, id, message }; empty when the catalog is valid.
function Catalog.Validate()
  local errors = {}
  local function add(rule, id, message)
    errors[#errors + 1] = { rule = rule, id = id, message = tostring(id) .. ": " .. message }
  end
  local locales = {}
  for _, code in ipairs(LOCALES) do
    locales[code] = ns.Locale.Get(code)
  end

  for _, category in ipairs(categoryList) do
    for _, code in ipairs(LOCALES) do
      if isBlank(locales[code][category.name]) then
        add(
          "missing_category_name",
          category.id,
          "category name key " .. tostring(category.name) .. " missing in " .. code
        )
      end
    end
  end

  local byId = {}
  for _, ach in ipairs(list) do
    local id = ach.id
    if isBlank(id) then
      add("missing_id", "?", "achievement without an id")
    elseif byId[id] then
      add("duplicate_id", id, "id registered more than once")
    else
      byId[id] = ach
    end
  end

  for _, ach in ipairs(list) do
    local id = ach.id
    if not isBlank(id) then
      if not categoryById[ach.category] then
        add("unknown_category", id, "category " .. tostring(ach.category) .. " does not exist")
      end
      if not POINTS[ach.points] then
        add("invalid_points", id, "points " .. tostring(ach.points) .. " is not allowed")
      elseif ach.feat and ach.points ~= 0 then
        add("feat_points", id, "a feat of strength has 0 points")
      end
      if not SCOPES[ach.scope] then
        add("invalid_scope", id, "scope " .. tostring(ach.scope) .. " is not character or account")
      end
      if ach.faction ~= nil and not FACTIONS[ach.faction] then
        add("invalid_faction", id, "faction " .. tostring(ach.faction) .. " is not Alliance or Horde")
      end

      local criteria = ach.criteria
      if type(criteria) ~= "table" or #criteria == 0 then
        add("no_criteria", id, "needs at least one criterion")
        criteria = {}
      end
      local require = ach.require
      if
        require ~= nil
        and require ~= "all"
        and not (type(require) == "number" and require >= 1 and require <= #criteria)
      then
        add("invalid_require", id, 'require must be "all" or a number between 1 and the number of criteria')
      end
      for _, criterion in ipairs(criteria) do
        local def = Catalog.CRITERIA_TYPES[criterion.type]
        if not def then
          add("unknown_criterion_type", id, "criterion type " .. tostring(criterion.type) .. " is not known")
        else
          if criterion.type == "meta" and not byId[criterion.key] then
            add("missing_meta", id, "meta criterion points to missing achievement " .. tostring(criterion.key))
          end
          if ach.scope == "account" and not def.derived then
            add("account_scope_type", id, "an account achievement cannot use the stored type " .. criterion.type)
          end
          if ach.scope == "character" and def.derived == "account" then
            add("character_scope_type", id, "a character achievement cannot use " .. criterion.type)
          end
        end
      end

      if ach.previous ~= nil then
        local previous = byId[ach.previous]
        if not previous then
          add("missing_previous", id, "previous " .. tostring(ach.previous) .. " does not exist")
        elseif previous.faction and ach.faction and previous.faction ~= ach.faction then
          add("faction_mismatch", id, "chain mixes factions with " .. ach.previous)
        end
      end

      for _, code in ipairs(LOCALES) do
        if isBlank(locales[code][Catalog.NameKey(id)]) then
          add("missing_name", id, "name key missing in " .. code)
        end
        if isBlank(locales[code][Catalog.DescKey(id)]) then
          add("missing_desc", id, "desc key missing in " .. code)
        end
      end
    end
  end

  findCycles(byId, add)
  return errors
end

ns.Catalog = Catalog

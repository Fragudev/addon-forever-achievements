local _, ns = ...

-- General achievements: the level chain and the first account achievement. ref.wotlk is the id of the original
-- WotLK achievement, used for the official names.
ns.Catalog.Register({
  {
    id = "level_10",
    category = "general.level",
    points = 10,
    scope = "character",
    icon = 236230,
    retroactive = true,
    ref = { wotlk = 6 },
    criteria = {
      { type = "level", value = 10 },
    },
  },
  {
    id = "level_20",
    category = "general.level",
    points = 10,
    scope = "character",
    icon = 236230,
    previous = "level_10",
    retroactive = true,
    ref = { wotlk = 7 },
    criteria = {
      { type = "level", value = 20 },
    },
  },
  {
    id = "level_30",
    category = "general.level",
    points = 10,
    scope = "character",
    icon = 236230,
    previous = "level_20",
    retroactive = true,
    ref = { wotlk = 8 },
    criteria = {
      { type = "level", value = 30 },
    },
  },
  {
    id = "level_40",
    category = "general.level",
    points = 10,
    scope = "character",
    icon = 236230,
    previous = "level_30",
    retroactive = true,
    ref = { wotlk = 9 },
    criteria = {
      { type = "level", value = 40 },
    },
  },
  {
    id = "level_50",
    category = "general.level",
    points = 10,
    scope = "character",
    icon = 236230,
    previous = "level_40",
    retroactive = true,
    ref = { wotlk = 10 },
    criteria = {
      { type = "level", value = 50 },
    },
  },
  {
    id = "level_60",
    category = "general.level",
    points = 10,
    scope = "character",
    icon = 236230,
    previous = "level_50",
    retroactive = true,
    ref = { wotlk = 11 },
    criteria = {
      { type = "level", value = 60 },
    },
  },
  {
    id = "account_three_60",
    category = "account.general",
    points = 10,
    scope = "account",
    icon = 236230,
    retroactive = true,
    ref = {},
    criteria = {
      { type = "account_level_count", key = 60, value = 3 },
    },
  },
})

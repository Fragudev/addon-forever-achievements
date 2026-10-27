-- Test catalog: one achievement per criterion type of plan section 5.2, plus a chain, metas, an n-of-m, a feat,
-- faction-only achievements and the account types. Ids start with "t_" so they never clash with the real data.
-- Usage: local fixture = dofile("tests/fixtures/catalog.lua"); fixture.Install(ns)

local function ach(id, criteria, extra)
  local def = {
    id = id,
    category = "general.misc",
    points = 5,
    scope = "character",
    icon = 134400,
    retroactive = true,
    ref = {},
    criteria = criteria,
  }
  for key, value in pairs(extra or {}) do
    def[key] = value
  end
  return def
end

local function one(id, criterionType, value, key, extra)
  return ach(id, { { type = criterionType, key = key, value = value } }, extra)
end

local list = {
  -- One achievement per progress type.
  one("t_level", "level", 10),
  one("t_money", "money", 1000),
  one("t_money_looted", "money_looted", 500),
  one("t_played", "played", 3600),
  one("t_quest_count", "quest_count", 5),
  one("t_quest_id", "quest_id", 1, 100),
  one("t_zone_quests", "zone_quests", 3, 12),
  one("t_explore_area", "explore_area", 1, 7),
  one("t_explore_zone", "explore_zone", 100, 12),
  one("t_reputation", "reputation", 42000, 72),
  one("t_reputation_count", "reputation_count", 2),
  one("t_skill", "skill", 300, 171),
  one("t_skill_count", "skill_count", 2),
  one("t_mount_count", "mount_count", 1),
  one("t_pet_count", "pet_count", 1),
  one("t_toy_count", "toy_count", 1),
  one("t_encounter", "encounter", 1, 1084),
  one("t_honor_kills", "honor_kills", 100),
  one("t_pvp_rank", "pvp_rank", 3),
  one("t_bg_win", "bg_win", 3),
  one("t_bg_played", "bg_played", 3),
  one("t_death", "death", 3),
  one("t_emote_target", "emote_target", 5, "squirrel"),
  one("t_item_obtained", "item_obtained", 1, 6948),
  one("t_equip_quality", "equip_quality", 3, 4),

  -- Chain over different types, so a later step can be satisfied before the earlier one.
  one("t_chain_1", "quest_count", 1),
  one("t_chain_2", "death", 2, nil, { previous = "t_chain_1" }),
  one("t_chain_3", "level", 30, nil, { previous = "t_chain_2" }),

  -- Metas: all of two, and any one of two.
  ach("t_meta", { { type = "meta", key = "t_bg_win" }, { type = "meta", key = "t_bg_played" } }, { points = 10 }),
  ach("t_meta_any", { { type = "meta", key = "t_death" }, { type = "meta", key = "t_pet_count" } }, { require = 1 }),

  -- n-of-m.
  ach("t_nofm", {
    { type = "quest_id", key = 1, value = 1 },
    { type = "quest_id", key = 2, value = 1 },
    { type = "quest_id", key = 3, value = 1 },
  }, { require = 2 }),

  -- Feat of strength (no points), hidden, and not retroactive.
  one("t_feat", "pvp_rank", 14, nil, { category = "feats.general", points = 0, feat = true }),
  one("t_hidden", "level", 14, nil, { hidden = true }),
  one("t_no_retro", "quest_count", 2, nil, { retroactive = false }),

  -- Faction only.
  one("t_horde_only", "level", 12, nil, { faction = "Horde" }),
  one("t_alliance_only", "level", 12, nil, { faction = "Alliance" }),

  -- Account scope.
  one("t_acc_levels", "account_level_count", 2, 10, { scope = "account", category = "account.general" }),
  one("t_acc_classes", "account_class_set", 3, nil, { scope = "account", category = "account.general" }),
  one("t_acc_money", "account_money", 5000, nil, { scope = "account", category = "account.general" }),
  one("t_acc_points", "account_points", 25, nil, { scope = "account", category = "account.general" }),
  one("t_acc_meta", "meta", 1, "t_hidden", { scope = "account", category = "account.general" }),
}

local strings = { enUS = {}, esES = {} }
for _, def in ipairs(list) do
  strings.enUS["ach." .. def.id .. ".name"] = "Test " .. def.id
  strings.enUS["ach." .. def.id .. ".desc"] = "Test description of " .. def.id
  strings.esES["ach." .. def.id .. ".name"] = "Prueba " .. def.id
  strings.esES["ach." .. def.id .. ".desc"] = "Descripción de prueba de " .. def.id
end

return {
  achievements = list,
  strings = strings,
  -- Registers the strings and the definitions in a loaded namespace.
  Install = function(ns)
    ns.Locale.Register("enUS", strings.enUS)
    ns.Locale.Register("esES", strings.esES)
    ns.Catalog.Register(list)
  end,
}

local _, ns = ...

-- Battleground instance map ids (the `key` of bg_win and bg_played).
-- Source: https://wago.tools/db2/Map (instance map ids of the Classic battlegrounds).

ns.Ref = ns.Ref or {}
ns.Ref.Battlegrounds = {
  warsong_gulch = 489,
  arathi_basin = 529,
  alterac_valley = 30,
}

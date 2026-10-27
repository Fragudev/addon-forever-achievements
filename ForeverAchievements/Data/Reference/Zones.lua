local _, ns = ...

-- Explorable zones: uiMapID plus the number of exploration overlays of that map.
-- Source: https://wago.tools/db2/UiMap (ids), https://wago.tools/db2/UiMapXMapArt and
-- https://wago.tools/db2/WorldMapOverlay
-- (`total` = WorldMapOverlay rows of the map art, which is what C_MapExplorationInfo.GetExploredMapTextures
-- counts).
-- Zones the Mainline client splits (The Barrens, Stranglethorn Vale) list one entry per half and the
-- achievement needs both.
-- Entries marked `unverified` depend on how Forever maps those zones; validate in game.

ns.Ref = ns.Ref or {}
ns.Ref.Zones = {
  elwynn = { map = 37, total = 15 },
  dun_morogh = { map = 27, total = 21 },
  tirisfal = { map = 18, total = 20 },
  westfall = { map = 52, total = 17 },
  loch_modan = { map = 48, total = 14 },
  silverpine = { map = 21, total = 18 },
  redridge = { map = 49, total = 16 },
  duskwood = { map = 47, total = 14 },
  wetlands = { map = 56, total = 18 },
  hillsbrad = { map = 25, total = 30 },
  arathi = { map = 14, total = 16 },
  badlands = { map = 15, total = 14 },
  swamp_of_sorrows = { map = 51, total = 14 },
  hinterlands = { map = 26, total = 18 },
  searing_gorge = { map = 32, total = 12 },
  blasted_lands = { map = 17, total = 14 },
  burning_steppes = { map = 36, total = 15 },
  western_plaguelands = { map = 22, total = 16 },
  eastern_plaguelands = { map = 23, total = 26 },
  deadwind_pass = { map = 42, total = 3 },
  northern_stranglethorn = { map = 50, total = 21 }, -- unverified
  cape_of_stranglethorn = { map = 210, total = 14 }, -- unverified
  durotar = { map = 1, total = 16 },
  mulgore = { map = 7, total = 18 },
  teldrassil = { map = 57, total = 14 },
  darkshore = { map = 62, total = 17 },
  northern_barrens = { map = 10, total = 17 }, -- unverified
  southern_barrens = { map = 199, total = 18 }, -- unverified
  ashenvale = { map = 63, total = 30 },
  stonetalon = { map = 65, total = 21 },
  thousand_needles = { map = 64, total = 15 },
  desolace = { map = 66, total = 21 },
  dustwallow = { map = 70, total = 15 },
  feralas = { map = 69, total = 24 },
  tanaris = { map = 71, total = 20 },
  azshara = { map = 76, total = 25 },
  ungoro = { map = 78, total = 14 },
  felwood = { map = 77, total = 16 },
  winterspring = { map = 83, total = 14 },
  silithus = { map = 81, total = 16 },
  moonglade = { map = 80, total = 4 },
}

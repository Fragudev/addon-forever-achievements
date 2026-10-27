local _, ns = ...

-- Dungeon encounter ids (DungeonEncounter.ID, the `encounterID` of ENCOUNTER_END).
-- Source: https://wago.tools/db2/DungeonEncounter (CSV), cross-checked with
-- https://warcraft.wiki.gg/wiki/DungeonEncounterID
-- Provisional until validated on the Forever client; entries marked `unverified` could not be confirmed
-- against the DB2 table.
-- Dungeons whose final boss differs between the original Classic encounter and the Mainline one list both
-- ids.

ns.Ref = ns.Ref or {}
ns.Ref.Encounters = {
  lucifron = 663,
  magmadar = 664,
  gehennas = 665,
  garr = 666,
  shazzrah = 667,
  baron_geddon = 668,
  sulfuron_harbinger = 669,
  golemagg = 670,
  majordomo_executus = 671,
  ragnaros = 672,
  onyxia = 1084,
  razorgore = 610,
  vaelastrasz = 611,
  broodlord_lashlayer = 612,
  firemaw = 613,
  ebonroc = 614,
  flamegor = 615,
  chromaggus = 616,
  nefarian = 617,
  venoxis = 784,
  jeklik = 785,
  marli = 786,
  mandokir = 787,
  edge_of_madness = 788,
  thekal = 789,
  gahzranka = 790,
  arlokk = 791,
  jindo = 792,
  hakkar = 793,
  kurinnaxx = 718,
  rajaxx = 719,
  moam = 720,
  buru = 721,
  ayamiss = 722,
  ossirian = 723,
  skeram = 709,
  silithid_royalty = 710,
  sartura = 711,
  fankriss = 712,
  viscidus = 713,
  huhuran = 714,
  twin_emperors = 715,
  ouro = 716,
  cthun = 717,
  anubrekhan = 1107,
  gluth = 1108,
  gothik = 1109,
  faerlina = 1110,
  grobbulus = 1111,
  heigan = 1112,
  razuvious = 1113,
  kelthuzad = 1114,
  loatheb = 1115,
  maexxna = 1116,
  noth = 1117,
  patchwerk = 1118,
  sapphiron = 1119,
  thaddius = 1120,
  four_horsemen = 1121,
  rfc_gordoth = 1446, -- Ragefire Chasm (Cataclysm-era encounter id) unverified
  wc_mutanus = 592,
  deadmines_van_cleef_classic = 167, -- Deadmines, original Classic id from the warcraft.wiki.gg list unverified
  deadmines_cookie = 2973, -- Deadmines, Mainline "Captain" Cookie unverified
  sfk_arugal_classic = 471, -- Shadowfang Keep, original Classic id from the warcraft.wiki.gg list unverified
  sfk_godfrey = 1072, -- Shadowfang Keep, Mainline Lord Godfrey unverified
  bfd_aku_mai = 1672,
  stockade_moloch = 1146, -- Stormwind Stockade, Mainline final boss unverified
  gnomeregan_thermaplugg = 382,
  rfk_charlga = 1661,
  sm_thalnos = 2818,
  sm_doan = 447,
  sm_herod = 448,
  sm_whitemane = 450,
  rfd_amnennar = 1666,
  uldaman_archaedas = 554,
  zf_ukorz = 600,
  mara_theradras = 429,
  st_eranikus = 493,
  brd_thaurissan = 245,
  lbrs_wyrmthalak = 275,
  -- Upper Blackrock Spire, id from the warcraft.wiki.gg list (page marks old ids as obsolete for dungeons) unverified
  ubrs_drakkisath = 280,
  dm_alzzin = 346,
  dm_tortheldrin = 361,
  dm_gordok = 368,
  scholo_gandling = 463,
  strat_balnazzar = 478,
  strat_rivendare = 484,
}

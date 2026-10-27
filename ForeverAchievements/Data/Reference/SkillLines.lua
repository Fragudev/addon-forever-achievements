local _, ns = ...

-- Skill line ids (SkillLine.ID, `skillLine` of GetProfessionInfo).
-- Source: https://wago.tools/db2/SkillLine (CSV).

ns.Ref = ns.Ref or {}
ns.Ref.SkillLines = {
  alchemy = 171,
  blacksmithing = 164,
  enchanting = 333,
  engineering = 202,
  herbalism = 182,
  leatherworking = 165,
  mining = 186,
  skinning = 393,
  tailoring = 197,
  cooking = 185,
  first_aid = 129,
  fishing = 356,
}

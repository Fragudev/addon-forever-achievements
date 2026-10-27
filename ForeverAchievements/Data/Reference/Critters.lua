local _, ns = ...

-- Creature (NPC) ids of the critters used by emote achievements.
-- Sources: https://wago.tools/db2/Creature and https://www.wowhead.com/classic (npc pages).
-- Forever may use different NPC ids than Classic Era; validate with the target GUID in game.

ns.Ref = ns.Ref or {}
ns.Ref.Critters = {
  rabbit = 721, -- DB2 Creature
  chicken = 620, -- DB2 Creature
  squirrel = 1412, -- wowhead Classic npc unverified
  prairie_dog = 2620, -- wowhead Classic npc; Forever page shows 252429 unverified
  cat = 6368, -- wowhead Classic npc unverified
  sheep = 1933, -- wowhead Classic npc unverified
  cow = 2442, -- wowhead Classic npc unverified
  toad = 1420, -- wowhead sitemap unverified
  fawn = 890, -- wowhead Classic npc unverified
  rat = 4075, -- DB2 Creature
}

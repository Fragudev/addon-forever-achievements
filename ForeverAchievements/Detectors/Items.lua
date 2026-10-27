local _, ns = ...

-- Items owned and gear quality. Facts:
--   item_obtained  key = item id, value = how many the player owns now (bags, bank and reagents); only for the ids the
--                  catalog references, and only when the player owns at least one
--   equip_quality  key = minimum quality (2 uncommon, 3 rare, 4 epic), value = how many equipped slots have at least
--                  that quality; published for the three keys whenever at least one slot could be read
-- Source (assumed, not measured): GetItemCount(id, true) on BAG_UPDATE_DELAYED; GetInventoryItemLink plus
-- C_Item.GetItemQualityByID on PLAYER_EQUIPMENT_CHANGED, over slots 1..18 except the shirt (4); the tabard (19) never
-- counts. Both events are coalesced. Both kinds of fact answer the retro scan (the current state); looting itself is
-- not read (CHAT_MSG_LOOT is unreliable during encounters), the bag count is.
local Detector = ns.Detector
local Items = Detector.Class("Items", {
  events = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" },
  throttled = { BAG_UPDATE_DELAYED = true, PLAYER_EQUIPMENT_CHANGED = true },
  retroType = "item_obtained",
})

-- Equipment slots that count: head to ranged, without the shirt (4); the tabard (19) is left out too.
Items.SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
Items.QUALITIES = { 2, 3, 4 }

function Items:ItemFacts()
  local ids = {}
  for id in pairs(Detector.ReferencedKeys(self.app.catalog, "item_obtained")) do
    if type(id) == "number" then
      ids[#ids + 1] = id
    end
  end
  table.sort(ids)
  local facts = {}
  for _, id in ipairs(ids) do
    local count = self.platform.GetItemCount(id, true)
    if count and count > 0 then
      facts[#facts + 1] = { type = "item_obtained", key = id, value = count }
    end
  end
  return facts
end

function Items:EquipFacts()
  local readable = 0
  local counts = {}
  for _, quality in ipairs(Items.QUALITIES) do
    counts[quality] = 0
  end
  for _, slot in ipairs(Items.SLOTS) do
    local quality = self.platform.GetEquippedItemQuality(slot)
    if quality then
      readable = readable + 1
      for _, minimum in ipairs(Items.QUALITIES) do
        if quality >= minimum then
          counts[minimum] = counts[minimum] + 1
        end
      end
    end
  end
  if readable == 0 then
    return {}
  end
  local facts = {}
  for _, minimum in ipairs(Items.QUALITIES) do
    facts[#facts + 1] = { type = "equip_quality", key = minimum, value = counts[minimum] }
  end
  return facts
end

function Items:Facts()
  local facts = self:ItemFacts()
  for _, fact in ipairs(self:EquipFacts()) do
    facts[#facts + 1] = fact
  end
  return facts
end

function Items:Handle(event)
  if event == "BAG_UPDATE_DELAYED" then
    self:Publish(self:ItemFacts())
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    self:Publish(self:EquipFacts())
  end
end

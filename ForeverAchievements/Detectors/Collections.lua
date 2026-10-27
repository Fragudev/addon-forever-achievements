local _, ns = ...

-- Collections. Facts: mount_count, pet_count, toy_count. Each one is published only when its journal answers
-- (Forever may lack some). Source (assumed, not measured):
--   mounts  C_MountJournal.GetMountIDs plus the "is collected" flag of GetMountInfoByID
--   pets    C_PetJournal.GetNumPets, owned pets
--   toys    C_ToyBox.GetNumLearnedDisplayedToys (the toy box filters may change it)
-- Events NEW_MOUNT_ADDED, NEW_PET_ADDED and NEW_TOY_ADDED re-read only their own journal, coalesced.
local Detector = ns.Detector
local Collections = Detector.Class("Collections", {
  events = { "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED" },
  throttled = { NEW_MOUNT_ADDED = true, NEW_PET_ADDED = true, NEW_TOY_ADDED = true },
  retroType = "mount_count",
})

local READERS = {
  mount_count = function(platform)
    return platform.GetCollectedMountCount()
  end,
  pet_count = function(platform)
    local _, owned = platform.GetNumPets()
    return owned
  end,
  toy_count = function(platform)
    return platform.GetNumLearnedToys()
  end,
}

local EVENT_TYPES = { NEW_MOUNT_ADDED = "mount_count", NEW_PET_ADDED = "pet_count", NEW_TOY_ADDED = "toy_count" }

function Collections:Read(types)
  local facts = {}
  for _, criterionType in ipairs(types) do
    local value = READERS[criterionType](self.platform)
    if value then
      facts[#facts + 1] = { type = criterionType, value = value }
    end
  end
  return facts
end

function Collections:Facts()
  return self:Read({ "mount_count", "pet_count", "toy_count" })
end

function Collections:Handle(event)
  local criterionType = EVENT_TYPES[event]
  if criterionType then
    self:Publish(self:Read({ criterionType }))
  end
end

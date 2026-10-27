local _, ns = ...

-- Money held, in copper. Facts: money. Source (assumed, not measured): GetMoney and PLAYER_MONEY. The snapshot
-- money feeds the account_money criterion.
local Detector = ns.Detector
local Money = Detector.Class("Money", { events = { "PLAYER_MONEY" }, retroType = "money" })

function Money:Facts()
  local money = self.platform.GetMoney()
  if not money then
    return {}
  end
  return { { type = "money", value = money } }
end

function Money:SnapshotFields()
  local money = self.platform.GetMoney()
  if not money then
    return nil
  end
  return { money = money }
end

function Money:Handle()
  local facts = self:Facts()
  if #facts == 0 then
    return
  end
  self:Publish(facts)
  self:QueueSnapshot({ money = facts[1].value })
end

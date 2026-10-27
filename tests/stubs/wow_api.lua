-- Minimal WoW API stubs so addon logic can run under busted outside the client.
-- Extend only with the APIs a spec actually needs.

_G.C_AddOns = {
  GetAddOnMetadata = function()
    return "@project-version@"
  end,
}

_G.CreateFrame = function()
  local frame = { scripts = {}, events = {} }
  function frame:RegisterEvent(event)
    self.events[event] = true
  end
  function frame:UnregisterEvent(event)
    self.events[event] = nil
  end
  function frame:SetScript(name, handler)
    self.scripts[name] = handler
  end
  return frame
end

_G.SlashCmdList = {}

-- Hooks are recorded so specs can fire them. Specs add the other client APIs they exercise themselves.
_G.hooksecurefunc = function(name, handler)
  if type(_G[name]) ~= "function" then
    error("hooksecurefunc: no function " .. tostring(name))
  end
  _G.__hooks = _G.__hooks or {}
  _G.__hooks[name] = handler
end

_G.CreateVector2D = function(x, y)
  return {
    x = x,
    y = y,
    GetXY = function(self)
      return self.x, self.y
    end,
  }
end

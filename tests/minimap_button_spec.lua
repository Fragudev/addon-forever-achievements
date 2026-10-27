local Env = dofile("tests/support/ui_env.lua")

describe("MinimapButton", function()
  local env, h, ns, ui

  before_each(function()
    env = Env.Build()
    h, ns = env.h, env.ns
    ui = ns.UI.Start(h.app)
  end)

  after_each(function()
    env.teardown()
  end)

  local function near(expected, actual)
    assert.are.near(expected, actual, 0.0001)
  end

  it("keeps an angle in [0, 360) and falls back for junk", function()
    local M = ns.MinimapButton
    assert.are.equal(0, M.NormalizeAngle(360))
    assert.are.equal(270, M.NormalizeAngle(-90))
    for _, value in ipairs({ "90", true, {}, 0 / 0, math.huge, -math.huge }) do
      assert.are.equal(M.DEFAULT_ANGLE, M.NormalizeAngle(value))
    end
    assert.are.equal(M.DEFAULT_ANGLE, M.NormalizeAngle(nil))
  end)

  it("puts the button on the circle", function()
    local M = ns.MinimapButton
    local x, y = M.Position(0, 80)
    near(80, x)
    near(0, y)
    x, y = M.Position(90, 80)
    near(0, x)
    near(80, y)
    for angle = 0, 350, 25 do
      x, y = M.Position(angle, 75)
      near(75, math.sqrt(x * x + y * y))
    end
    x, y = M.Position("junk", 80)
    local ex, ey = M.Position(M.DEFAULT_ANGLE, 80)
    assert.are.same({ ex, ey }, { x, y })
  end)

  it("measures the angle of the cursor", function()
    local M = ns.MinimapButton
    near(0, M.AngleFromCursor(0, 0, 10, 0))
    near(90, M.AngleFromCursor(0, 0, 0, 10))
    near(180, M.AngleFromCursor(5, 5, -5, 5))
    near(270, M.AngleFromCursor(0, 0, 0, -10))
  end)

  it("builds the button at the saved angle and shows the logo masked", function()
    local button = ui.minimap.button
    assert.is_true(button:IsShown())
    local x, y = ns.MinimapButton.Position(200, 70 + ns.MinimapButton.RADIUS_MARGIN)
    near(x, button.points[1][4])
    near(y, button.points[1][5])
    local logos = 0
    for _, region in ipairs(button.children) do
      if region.texture == ns.MinimapButton.LOGO then
        logos = logos + 1
      end
    end
    assert.are.equal(1, logos)
  end)

  it("toggles the window on a left click only", function()
    local button = ui.minimap.button
    button.scripts.OnClick(button, "RightButton")
    assert.is_false(ui:IsOpen())
    button.scripts.OnClick(button, "LeftButton")
    assert.is_true(ui:IsOpen())
    button.scripts.OnClick(button, "LeftButton")
    assert.is_false(ui:IsOpen())
  end)

  it("follows the cursor while dragging and saves the angle", function()
    local button = ui.minimap.button
    _G.GetCursorPosition = function()
      return 0, 100
    end
    _G.Minimap.GetCenter = function()
      return 0, 0
    end
    button.scripts.OnDragStart(button)
    button.scripts.OnUpdate()
    near(90, h.settings:Get("minimap").angle)
    button.scripts.OnDragStop(button)
    assert.is_nil(button.scripts.OnUpdate)
    -- A minimap without a position (not laid out yet) is ignored.
    _G.Minimap.GetCenter = function() end
    assert.has_no.errors(function()
      ui.minimap:Follow()
    end)
    near(90, h.settings:Get("minimap").angle)
  end)

  it("shows a tooltip and hides it", function()
    local lines = {}
    _G.GameTooltip = {
      SetOwner = function() end,
      AddLine = function(_, text)
        lines[#lines + 1] = text
      end,
      Show = function() end,
      Hide = function() end,
    }
    local button = ui.minimap.button
    button.scripts.OnEnter()
    assert.are.equal("Forever Achievements", lines[1])
    assert.are.equal(3, #lines)
    button.scripts.OnLeave()
    button.scripts.OnDragStart(button)
  end)

  it("hides and shows from the settings", function()
    ui.minimap:SetHidden(true)
    assert.is_false(ui.minimap.button:IsShown())
    assert.is_true(ui.minimap:IsHidden())
    ui.minimap:SetHidden(false)
    assert.is_true(ui.minimap.button:IsShown())
    h.store:Settings().minimap = { angle = "bad" }
    assert.are.equal(ns.MinimapButton.DEFAULT_ANGLE, ui.minimap:Settings().angle)
  end)

  it("builds nothing without a Minimap", function()
    _G.Minimap = nil
    local bare = ns.MinimapButton.New(ui)
    assert.is_nil(bare.button)
    assert.has_no.errors(function()
      bare:Refresh()
      bare:Place()
    end)
  end)
end)

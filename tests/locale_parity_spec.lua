local Loader = dofile("tests/support/loader.lua")
local fixture = dofile("tests/fixtures/catalog.lua")

describe("Locale parity", function()
  local ns = Loader.Full()
  fixture.Install(ns)

  local function placeholders(text)
    local found = {}
    for spec in text:gmatch("%%[%a%d]") do
      found[#found + 1] = spec
    end
    return table.concat(found, ",")
  end

  it("has every enUS key in esES, non-empty", function()
    local en, es = ns.Locale.Get("enUS"), ns.Locale.Get("esES")
    local count = 0
    for key, text in pairs(en) do
      count = count + 1
      assert.is_true(type(text) == "string" and text ~= "", "empty enUS text for " .. key)
      assert.is_true(type(es[key]) == "string" and es[key] ~= "", "esES is missing " .. key)
      assert.are.equal(placeholders(text), placeholders(es[key]), "placeholders differ for " .. key)
    end
    assert.is_true(count > 50)
  end)

  it("translates the name and description of every catalog achievement", function()
    local en, es = ns.Locale.Get("enUS"), ns.Locale.Get("esES")
    for _, ach in ipairs(ns.Catalog.All()) do
      for _, key in ipairs({ ns.Catalog.NameKey(ach.id), ns.Catalog.DescKey(ach.id) }) do
        assert.is_true(type(en[key]) == "string" and en[key] ~= "", "enUS is missing " .. key)
        assert.is_true(type(es[key]) == "string" and es[key] ~= "", "esES is missing " .. key)
      end
    end
    assert.is_true(ns.Catalog.Count() >= 400)
  end)

  it("has no esES key without an enUS one", function()
    local en = ns.Locale.Get("enUS")
    for key in pairs(ns.Locale.Get("esES")) do
      assert.is_not_nil(en[key], "enUS is missing " .. key)
    end
  end)
end)

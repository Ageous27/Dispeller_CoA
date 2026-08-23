-- Confirmed Conquest of Azeroth spells (db.ascension.gg + in-game dump).
-- Other CoA cleanses are learned from the live spellbook tooltip.

DispellerCoA = DispellerCoA or {}

local CATALOG = {
    -- Templar
    { id = 525051, name = "Rebuke", types = { "Magic", "Poison", "Disease" } },

    -- Dwarf racial (CoA spell ID from /dcoa dump)
    { id = 1120594, name = "Stoneform", types = { "Poison", "Disease", "Bleed" }, selfOnly = true },

    -- Sun Cleric (class skills list on db.ascension.gg)
    { name = "Cleanser of Sins", types = { "Magic", "Poison", "Disease" }, classes = { 27 } },
}

local byId = {}
local byName = {}

local i
for i = 1, #CATALOG do
    local e = CATALOG[i]
    if e.id then
        byId[e.id] = e
    end
    if e.name and not byName[e.name] then
        byName[e.name] = e
    end
end

DispellerCoA.SpellCatalog = CATALOG
DispellerCoA.CatalogById = byId
DispellerCoA.CatalogByName = byName

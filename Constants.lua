DispellerCoA = DispellerCoA or {}

local C = {}
DispellerCoA.C = C

C.TYPES = { "Magic", "Curse", "Poison", "Disease", "Bleed" }

C.TYPE_SET = {
    Magic = true,
    Curse = true,
    Poison = true,
    Disease = true,
    Bleed = true,
}

C.BLEED_TYPES = {
    Bleed = true,
    Bleeding = true,
}

C.COA_CLASSES = {
    [12] = "Barbarian",
    [13] = "Witch Doctor",
    [14] = "Felsworn",
    [15] = "Witch Hunter",
    [16] = "Stormbringer",
    [17] = "Knight of Xoroth",
    [18] = "Guardian",
    [19] = "Templar",
    [20] = "Bloodmage",
    [21] = "Ranger",
    [22] = "Chronomancer",
    [23] = "Necromancer",
    [24] = "Pyromancer",
    [25] = "Cultist",
    [26] = "Starcaller",
    [27] = "Sun Cleric",
    [28] = "Tinker",
    [29] = "Venomancer",
    [30] = "Reaper",
    [31] = "Primalist",
    [32] = "Runemaster",
}

C.STATUS = {
    MISSING = "MISSING",
    FAR = "FAR",
    BLACKLISTED = "BLACKLISTED",
    AFFLICTED = "AFFLICTED",
    CLEAR = "CLEAR",
}

C.CLICK_COLORS = {
    { 0.15, 0.45, 1.00 }, -- left / Magic: blue
    { 0.72, 0.18, 1.00 }, -- right / Curse: purple
    { 0.10, 1.00, 0.18 }, -- shift-left / Poison: green
    { 1.00, 0.50, 0.00 }, -- shift-right / Disease: orange
    { 1.00, 0.06, 0.06 }, -- ctrl-left / Bleed: red
}

C.COLOR_CLEAR = { 0.11, 0.49, 0.20 }
C.COLOR_FAR = { 0.55, 0.28, 0.70 }
C.COLOR_BLACK = { 0.08, 0.08, 0.08 }
C.COLOR_GONE = { 0.45, 0.45, 0.45 }
C.COLOR_BORDER = { 0.05, 0.05, 0.05 }

C.SOUND_AFFLICTED = "Sound\\Doodad\\BellTollTribal.wav"
C.SOUND_FAILED = "Sound\\Interface\\Error.wav"

C.MAX_DEBUFFS = 40
C.MAX_MUFS = 40
C.SCAN_THROTTLE = 0.12

C.CLICK_SLOTS = {
    { mod = "", button = "1" },
    { mod = "", button = "2" },
    { mod = "shift-", button = "1" },
    { mod = "shift-", button = "2" },
    { mod = "ctrl-", button = "1" },
}

function DispellerCoA.DefaultDB()
    return {
        enabled = true,
        showPets = false,
        showLiveList = true,
        playSound = true,
        blacklistSeconds = 8,
        mufSize = 20,
        mufOpacity = 80,
        mufSpacing = 2,
        maxMUFs = 25,
        typeEnabled = {
            Magic = true,
            Curse = true,
            Poison = true,
            Disease = true,
            Bleed = true,
        },
        typeOrder = { "Magic", "Curse", "Poison", "Disease", "Bleed" },
        clickBinds = { "auto", "auto", "auto", "auto", "auto" },
        overrides = {},
        prio = {},
        skip = {},
        point = "CENTER",
        relPoint = "CENTER",
        x = 180,
        y = 80,
        livePoint = "CENTER",
        liveRelPoint = "CENTER",
        liveX = 180,
        liveY = -80,
    }
end

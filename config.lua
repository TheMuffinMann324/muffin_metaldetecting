Config = {}

-- Target system - Options: 'qb-target' or 'ox_target'
Config.TargetSystem = 'ox_target'

-- Target/Interaction settings
Config.UseThirdEye = false -- Set to true to use third eye target system, false to use floating marker
Config.MarkerType = 2 -- Marker type when not using third eye (1 = cylinder, 2 = arrow, etc.)
Config.MarkerColor = {r = 255, g = 255, b = 0, a = 200} -- Marker color (yellow semi-transparent)
Config.MarkerScale = vector3(0.3, 0.3, 0.3) -- Marker size

-- Debug options and blips
Config.Debug = false -- Set to true to enable debug features
Config.ShowZones = false -- Set to true to show zone polygons
Config.ShowBlips = true -- Set to true to show zone blips on map

-- Item names
Config.MetalDetectorItem = 'metaldetector' -- Item name for the metal detector

-- Rake settings
Config.AllowRaking = true -- Set to true to enable raking functionality
Config.RakeItem = 'rake' -- Item name for the rake
Config.RakeEmote = 'rake2' -- Animation for raking
Config.RakeTime = 8000 -- Time in ms for raking animation
Config.RakeFailChance = 30 -- Percentage chance (0-100) to find nothing when raking

-- Emotes
Config.ScanEmote = 'digiscan' -- Scanning emote
Config.DigEmote = 'garden' -- Digging emote

-- Zones where metal detecting is allowed
Config.Zones = {
    {
        name = "beach",
        label = "Los Santos Beach Detecting", -- Blip name
        blipSprite = 618, -- Sand castle
        blipColor = 46, -- Light orange
        blipScale = 0.8,
        points = {
            -- Vespucci Beach to East Los Santos Beach
            vector3(-1238.66, -1873.13, 0.96), --So many vectors, so little time, mapped out the beach
            vector3(-1260.13, -1847.01, 1.10),
            vector3(-1322.35, -1746.63, 1.14),
            vector3(-1383.13, -1661.64, 0.89),
            vector3(-1439.54, -1567.25, 0.31),
            vector3(-1477.89, -1502.45, 0.81),
            vector3(-1501.53, -1454.88, 0.54),
            vector3(-1518.11, -1370.05, 1.12),
            vector3(-1554.94, -1261.82, 0.86),
            vector3(-1637.19, -1133.31, 1.09),
            vector3(-1562.41, -1046.22, 7.24),
            vector3(-1469.35, -1085.92, 3.37),
            vector3(-1500.83, -1125.35, 0.19), 
            vector3(-1483.74, -1134.76, 0.75),
            vector3(-1424.96, -1132.42, 3.14),
            vector3(-1429.85, -1218.06, 3.81), 
            vector3(-1425.23, -1242.25, 4.45),
            vector3(-1388.13, -1285.99, 4.36),
            vector3(-1395.50, -1333.86, 4.17),
            vector3(-1405.78, -1400.04, 3.68), 
            vector3(-1368.49, -1479.41, 4.44),
            vector3(-1373.10, -1513.88, 4.36), 
            vector3(-1347.64, -1557.17, 4.44), 
            vector3(-1339.46, -1581.76, 4.35), 
            vector3(-1317.19, -1620.22, 4.38),
            vector3(-1216.61, -1768.18, 3.69),
            vector3(-1226.16, -1790.91, 3.61),
            vector3(-1197.94, -1833.69, 3.91) 
        },
        minZ = -5.0, -- Below sea level to catch the shoreline
        maxZ = 30.0, -- High enough for any elevated parts of the beach
        allowRaking = true -- Can use rake in this zone
    },
    {
        name = "paleto_beach",
        label = "Paleto Bay Beach Detecting", 
        blipSprite = 618,
        blipColor = 47, -- Slightly different color to distinguish
        blipScale = 0.8,
        points = {
            vector3(-219.19, 6571.34, 2.72), --So many vectors, so little time, mapped out the beach
            vector3(-260.24, 6612.30, 1.47),
            vector3(-288.87, 6595.13, 1.64),
            vector3(-321.73, 6552.74, 2.27),
            vector3(-361.34, 6525.95, 2.12),
            vector3(-379.84, 6505.32, 2.55), 
            vector3(-432.07, 6485.61, 2.82), 
            vector3(-482.37, 6453.75, 2.45),
            vector3(-562.00, 6413.33, 2.64),
            vector3(-605.92, 6387.50, 3.48),
            vector3(-627.94, 6357.07, 2.70),
            vector3(-578.68, 6315.12, 2.21),
            vector3(-548.66, 6348.50, 3.75), 
            vector3(-527.26, 6369.84, 3.34),
            vector3(-522.81, 6373.05, 3.04),
            vector3(-460.21, 6393.79, 2.21),
            vector3(-396.76, 6422.63, 3.98),
            vector3(-376.56, 6452.16, 2.06),
            vector3(-305.35, 6492.08, 3.03),
            vector3(-261.72, 6528.02, 2.39)
        },
        minZ = -2.0,
        maxZ = 12.0,
        allowRaking = true
    }
    -- Add more zones as needed, Y dont have to copy me and map out beaches with vectors, a simple box will do im just picky.
}

-- Treasure settings
Config.TreasureRadius = 30.0 -- Maximum distance from player for treasure to spawn
Config.DigRadius = 5.0 -- Distance to treasure required to show dig option
Config.DigTime = 5000 -- Time in ms for digging animation

-- Sounds
Config.BeepVolume = 0.2
Config.MaxBeepRate = 0.2 -- Fastest beep rate (seconds)
Config.MinBeepRate = 1.0 -- Slowest beep rate (seconds)

-- Rewards - Items that can be found with metal detector
Config.Rewards = {
    {item = "glass", label = "Gold Coin", min = 1, max = 3, chance = 30},
    {item = "glass", label = "Silver Coin", min = 1, max = 5, chance = 50},
    {item = "glass", label = "Antique Jewelry", min = 1, max = 1, chance = 20},
    {item = "glass", label = "Rolex Watch", min = 1, max = 1, chance = 10},
    {item = "glass", label = "Diamond", min = 1, max = 1, chance = 5},
    {item = "glass", label = "Old Key", min = 1, max = 1, chance = 15},
    {item = "glass", label = "Metal Scrap", min = 1, max = 8, chance = 70},
    -- Add more items as needed
}

-- Rake rewards - Items that can be found when raking the sand
Config.RakeRewards = {
    {item = "glass", label = "Seashell", min = 1, max = 4, chance = 60},
    {item = "glass", label = "Pearl", min = 1, max = 1, chance = 10},
    {item = "glass", label = "Starfish", min = 1, max = 2, chance = 35},
    {item = "glass", label = "Sand Dollar", min = 1, max = 2, chance = 40},
    {item = "glass", label = "Ancient Coin", min = 1, max = 1, chance = 5},
    {item = "glass", label = "Plastic Bottle", min = 1, max = 3, chance = 50},
    {item = "glass", label = "Small Crab", min = 1, max = 1, chance = 15},
    -- Add more items as needed
}

-- Cooldown between uses (in seconds)
Config.Cooldown = 2
Config.RakeCooldown = 10 -- Cooldown for rake usage

-- Keybinds
Config.CancelKey = 73 -- X key (default)

-- Allows players to dig up buried treasure 
Config.MessageBottle = {
    enabled = true,                 -- Enable or disable message in a bottle feature
    bottleItem = "messagebottle",   -- Item name for the message in a bottle
    bottleChance = 10,              -- Percentage chance to find a bottle when digging (0-100)
    treasureLocations = {           -- Predefined treasure locations
        vector4(-86.67, 6765.68, 1.82, 330),  -- Vespucci Beach
        vector4(1339.51, 5040.21, 136.66, 246), -- Del Perro Beach
        vector4(1663.71, 4494.13, 32.33, 132),   -- Alamo Sea shore
        vector4(156.32, 3656.80, 32.31, 68),     -- Paleto Bay coast
        vector4(1532.94, -2747.22, 2.03, 270),    -- East coast
        -- Add more locations as needed
    },
    digTime = 10000,                -- Time in ms for digging up buried treasure
    useThirdEye = false,             -- Use third eye for buried treasure (if false, uses marker)
    treasureRadius = 3.0,           -- Radius around the treasure for digging interaction
    specialRewards = {              -- Special rewards for buried treasure (higher value rewards)
        {item = "goldbar", label = "Gold Bar", min = 1, max = 2, chance = 50},
        {item = "diamond_ring", label = "Diamond Ring", min = 1, max = 1, chance = 30},
        {item = "goldchain", label = "Gold Chain", min = 1, max = 3, chance = 60},
        {item = "cryptostick", label = "Crypto Stick", min = 1, max = 1, chance = 10},
        {item = "rolex", label = "Rolex Watch", min = 1, max = 2, chance = 40},
        -- Add more special rewards as desired
    }
}

-- Leaderboard settings
Config.Leaderboard = {
    refreshTime = 5 * 60,      -- How often to refresh leaderboard data in seconds (5 minutes)
    rareItemThreshold = 10,    -- Item chance below this is considered "rare" for leaderboard tracking
    itemValues = {             -- Value of each item for the value leaderboard
        ["Gold Coin"] = 250,
        ["Silver Coin"] = 100,
        ["Antique Jewelry"] = 500,
        ["Rolex Watch"] = 750,
        ["Diamond"] = 1000,
        ["Old Key"] = 300,
        ["Metal Scrap"] = 15,
        ["Seashell"] = 5,
        ["Pearl"] = 400,
        ["Starfish"] = 30,
        ["Sand Dollar"] = 25,
        ["Ancient Coin"] = 800,
        ["Plastic Bottle"] = 2,
        ["Small Crab"] = 50,
    }
}



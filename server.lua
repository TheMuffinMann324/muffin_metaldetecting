local QBCore = exports['qb-core']:GetCoreObject()

-- Database initialization (simplified)
local function InitializeDatabase()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS muffin_metal_detecting (
            id VARCHAR(50) PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            name VARCHAR(255) NOT NULL,
            total_items INT DEFAULT 0,
            total_value INT DEFAULT 0,
            total_time INT DEFAULT 0,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
end

-- Initialize stats for a player if they don't exist
local function EnsurePlayerStats(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    
    local citizenid = Player.PlayerData.citizenid
    local name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- Check if player exists in database
    MySQL.query('SELECT * FROM muffin_metal_detecting WHERE citizenid = ?', {citizenid}, function(result)
        if result and #result > 0 then return end
        
        -- Player doesn't exist, create entry
        MySQL.insert('INSERT INTO muffin_metal_detecting (id, citizenid, name) VALUES (?, ?, ?)', 
            {citizenid .. '-' .. math.random(100000, 999999), citizenid, name})
    end)
    
    return citizenid
end

-- Cache for leaderboard data to avoid frequent DB queries
local leaderboardCache = {
    data = {},
    lastUpdated = 0
}

-- Get leaderboard data
local function GetLeaderboardData(forceRefresh)
    local currentTime = os.time()
    
    -- Return cached data if it's fresh enough
    if not forceRefresh and leaderboardCache.lastUpdated > 0 and 
       currentTime - leaderboardCache.lastUpdated < Config.Leaderboard.refreshTime then
        return leaderboardCache.data
    end
    
    -- Otherwise, query fresh data
    local leaderboard = {}
    local result = MySQL.query.await('SELECT id, name, total_items, total_value FROM muffin_metal_detecting ORDER BY total_items DESC LIMIT 100')
    
    if result then
        for i = 1, #result do
            table.insert(leaderboard, {
                id = result[i].id,
                name = result[i].name,
                totalItems = result[i].total_items,
                totalValue = result[i].total_value
            })
        end
    end
    
    -- Update cache
    leaderboardCache.data = leaderboard
    leaderboardCache.lastUpdated = currentTime
    
    return leaderboard
end

-- Get player stats (simplified version)
local function GetPlayerStats(citizenid)
    if not citizenid then return nil end
    
    local result = MySQL.query.await('SELECT * FROM muffin_metal_detecting WHERE citizenid = ?', {citizenid})
    
    if result and #result > 0 then
        local data = result[1]
        
        return {
            id = data.id,
            totalItems = data.total_items,
            totalValue = data.total_value,
            totalTime = data.total_time
        }
    end
    
    return {
        id = nil,
        totalItems = 0,
        totalValue = 0,
        totalTime = 0
    }
end

-- Update player stats with new finds (simplified version)
local function UpdatePlayerStats(citizenid, itemLabel, amount)
    if not citizenid then return end
    
    -- Get item value from config
    local itemValue = Config.Leaderboard.itemValues[itemLabel] or 0
    local totalValue = itemValue * amount
    
    -- Update database with simplified stats
    MySQL.update([[
        UPDATE muffin_metal_detecting 
        SET total_items = total_items + ?,
            total_value = total_value + ?,
            last_updated = CURRENT_TIMESTAMP
        WHERE citizenid = ?
    ]], {
        amount,        -- Add to total items
        totalValue,    -- Add to total value
        citizenid      -- Where clause
    })
    
    -- Mark cache as needing refresh
    leaderboardCache.lastUpdated = 0
end

-- Update player hunting time
local function UpdatePlayerTime(citizenid, seconds)
    if not citizenid then return end
    
    MySQL.update('UPDATE muffin_metal_detecting SET total_time = total_time + ? WHERE citizenid = ?', 
        {seconds, citizenid})
end

-- Register metal detector as usable item
QBCore.Functions.CreateUseableItem(Config.MetalDetectorItem, function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        -- Make sure player has stats entry
        EnsurePlayerStats(src)
        TriggerClientEvent('muffin_metaldetecting:client:useMetalDetector', src)
    end
end)

-- Register rake as usable item if enabled
if Config.AllowRaking then
    QBCore.Functions.CreateUseableItem(Config.RakeItem, function(source, item)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            -- Make sure player has stats entry
            EnsurePlayerStats(src)
            TriggerClientEvent('muffin_metaldetecting:client:useRake', src)
        end
    end)
end

-- Give random reward to player
RegisterNetEvent('muffin_metaldetecting:server:giveTreasureReward', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Calculate total chance for weighted random selection
    local totalChance = 0
    for _, reward in pairs(Config.Rewards) do
        totalChance = totalChance + reward.chance
    end
    
    -- Generate random number based on total chance
    local random = math.random(totalChance)
    local currentChance = 0
    local selectedReward = nil
    
    -- Select reward based on weighted chance
    for _, reward in pairs(Config.Rewards) do
        currentChance = currentChance + reward.chance
        if random <= currentChance then
            selectedReward = reward
            break
        end
    end
    
    -- If we have a valid reward, give it to the player
    if selectedReward then
        -- Determine amount
        local amount = math.random(selectedReward.min, selectedReward.max)
        
        -- Add item to player inventory
        if Player.Functions.AddItem(selectedReward.item, amount) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[selectedReward.item], "add")
            TriggerClientEvent('QBCore:Notify', src, 'You found ' .. amount .. 'x ' .. selectedReward.label, 'success')
            
            -- Track for leaderboard (simplified)
            local citizenid = Player.PlayerData.citizenid
            UpdatePlayerStats(citizenid, selectedReward.label, amount)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Your inventory is full!', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'You didn\'t find anything valuable', 'error')
    end

    -- Check for message in a bottle after regular rewards
    TriggerEvent('muffin_metaldetecting:server:checkForMessageBottle')
end)

-- Give random rake reward to player
RegisterNetEvent('muffin_metaldetecting:server:giveRakeReward', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check for fail chance first
    if math.random(100) <= Config.RakeFailChance then
        TriggerClientEvent('QBCore:Notify', src, 'You raked through the sand but found nothing interesting', 'error')
        return
    end
    
    -- Calculate total chance for weighted random selection
    local totalChance = 0
    for _, reward in pairs(Config.RakeRewards) do
        totalChance = totalChance + reward.chance
    end
    
    -- Generate random number based on total chance
    local random = math.random(totalChance)
    local currentChance = 0
    local selectedReward = nil
    
    -- Select reward based on weighted chance
    for _, reward in pairs(Config.RakeRewards) do
        currentChance = currentChance + reward.chance
        if random <= currentChance then
            selectedReward = reward
            break
        end
    end
    
    -- If we have a valid reward, give it to the player
    if selectedReward then
        -- Determine amount
        local amount = math.random(selectedReward.min, selectedReward.max)
        
        -- Add item to player inventory
        if Player.Functions.AddItem(selectedReward.item, amount) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[selectedReward.item], "add")
            TriggerClientEvent('QBCore:Notify', src, 'You raked up ' .. amount .. 'x ' .. selectedReward.label, 'success')
            
            -- Track for leaderboard (simplified)
            local citizenid = Player.PlayerData.citizenid
            UpdatePlayerStats(citizenid, selectedReward.label, amount)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Your inventory is full!', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'You didn\'t find anything interesting', 'error')
    end

    -- Check for message in a bottle after regular rewards
    TriggerEvent('muffin_metaldetecting:server:checkForMessageBottle')
end)

-- Give message in a bottle during treasure finds
RegisterNetEvent('muffin_metaldetecting:server:checkForMessageBottle', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not Config.MessageBottle.enabled then return end
    
    -- Check if player should find a message bottle based on chance
    if math.random(100) <= Config.MessageBottle.bottleChance then
        -- Add bottle to player inventory
        if Player.Functions.AddItem(Config.MessageBottle.bottleItem, 1) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.MessageBottle.bottleItem], "add")
            TriggerClientEvent('QBCore:Notify', src, 'You found a message in a bottle!', 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Your inventory is full!', 'error')
        end
    end
end)

-- Register message bottle as usable item
QBCore.Functions.CreateUseableItem(Config.MessageBottle.bottleItem, function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Remove the bottle when used
    Player.Functions.RemoveItem(Config.MessageBottle.bottleItem, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.MessageBottle.bottleItem], "remove")
    
    -- Trigger client event to create treasure map waypoint
    TriggerClientEvent('muffin_metaldetecting:client:readTreasureMap', src)
end)

-- Handle buried treasure digging rewards
RegisterNetEvent('muffin_metaldetecting:server:digBuriedTreasure', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Calculate total chance for weighted random selection
    local totalChance = 0
    for _, reward in pairs(Config.MessageBottle.specialRewards) do
        totalChance = totalChance + reward.chance
    end
    
    -- Generate random number based on total chance
    local random = math.random(totalChance)
    local currentChance = 0
    local selectedReward = nil
    
    -- Select reward based on weighted chance
    for _, reward in pairs(Config.MessageBottle.specialRewards) do
        currentChance = currentChance + reward.chance
        if random <= currentChance then
            selectedReward = reward
            break
        end
    end
    
    -- If we have a valid reward, give it to the player
    if selectedReward then
        -- Determine amount
        local amount = math.random(selectedReward.min, selectedReward.max)
        
        -- Add item to player inventory
        if Player.Functions.AddItem(selectedReward.item, amount) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[selectedReward.item], "add")
            TriggerClientEvent('QBCore:Notify', src, 'You found buried treasure: ' .. amount .. 'x ' .. selectedReward.label, 'success')
            
            -- Track for leaderboard
            local citizenid = Player.PlayerData.citizenid
            UpdatePlayerStats(citizenid, selectedReward.label, amount)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Your inventory is full!', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'The treasure chest was empty!', 'error')
    end
end)

-- Track player hunting time
RegisterNetEvent('muffin_metaldetecting:server:trackTime', function(seconds)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    UpdatePlayerTime(citizenid, seconds)
end)

-- Make sure the command registration is proper
-- Open leaderboard command
QBCore.Commands.Add('detectingboard', 'View the Metal Detecting Leaderboard', {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Make sure player has stats entry
    local citizenid = EnsurePlayerStats(src)
    
    -- Get leaderboard data
    local leaderboardData = GetLeaderboardData(false)
    local playerStats = GetPlayerStats(citizenid)
    
    -- Find player ID in leaderboard
    local playerLeaderboardId = nil
    for _, entry in ipairs(leaderboardData) do
        if entry.id and citizenid and entry.id:find(citizenid) then
            playerLeaderboardId = entry.id
            break
        end
    end
    
    -- Send data to client
    TriggerClientEvent('muffin_metaldetecting:client:openLeaderboard', src, leaderboardData, playerStats, playerLeaderboardId)
end)

-- Add this event handler (or fix the existing one)
RegisterNetEvent('muffin_metaldetecting:server:requestLeaderboard')
AddEventHandler('muffin_metaldetecting:server:requestLeaderboard', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Make sure player has stats entry
    local citizenid = EnsurePlayerStats(src)
    
    -- Get leaderboard data
    local leaderboardData = GetLeaderboardData(false)
    local playerStats = GetPlayerStats(citizenid)
    
    -- Find player ID in leaderboard
    local playerLeaderboardId = nil
    for _, entry in ipairs(leaderboardData) do
        if entry.id:find(citizenid) then
            playerLeaderboardId = entry.id
            break
        end
    end
    
    -- Send data to client
    TriggerClientEvent('muffin_metaldetecting:client:openLeaderboard', src, leaderboardData, playerStats, playerLeaderboardId)
end)

-- Initialize on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    InitializeDatabase()
    -- Load leaderboard data into cache
    GetLeaderboardData(true)
end)

local QBCore = exports['qb-core']:GetCoreObject()
local treasurePos = nil
local activeZone = nil
local isScanning = false
local beepLoop = nil
local cooldownActive = false
local currentZone = nil
local zoneBlips = {}
local debugZonePolys = {}

-- Add these variables at the top with other local variables
local startTime = 0
local isLeaderboardOpen = false
local activeTreasureLocation = nil
local treasureBlip = nil
local isTreasureMarked = false

-- Load models and audio
CreateThread(function()
    -- Request sound dictionaries
    RequestAmbientAudioBank("DLC_HEIST_FLEECA_SOUNDSET", 0)
    RequestAmbientAudioBank("HUD_MINI_GAME_SOUNDSET", 0)
end)

-- Target system helper functions
local function AddBoxZone(name, points, options, minZ, maxZ)
    if Config.TargetSystem == 'qb-target' then
        exports['qb-target']:AddPolyZone(name, points, {
            name = name,
            debugPoly = Config.Debug,
            minZ = minZ,
            maxZ = maxZ
        }, options)
    elseif Config.TargetSystem == 'ox_target' then
        exports.ox_target:addPolyZone({
            coords = points,
            debug = Config.Debug,
            options = options.options
        })
    end
end

local function AddCircleZone(name, coords, radius, options)
    if Config.TargetSystem == 'qb-target' then
        exports['qb-target']:AddCircleZone(name, coords, radius, {
            name = name,
            debugPoly = Config.Debug,
            useZ = true
        }, options)
    elseif Config.TargetSystem == 'ox_target' then
        exports.ox_target:addSphereZone({
            coords = coords,
            radius = radius,
            debug = Config.Debug,
            options = options.options
        })
    end
end

local function RemoveZone(name)
    if Config.TargetSystem == 'qb-target' then
        -- Fix for qb-target - use RemovePolyZone for polygon zones and RemoveCircleZone for circle zones
        if name:find("treasure_zone_") then
            exports['qb-target']:RemovePolyZone(name)
        else
            exports['qb-target']:RemoveCircleZone(name)
        end
    elseif Config.TargetSystem == 'ox_target' then
        exports.ox_target:removeZone(name)
    end
end

-- Create zone blips
function CreateZoneBlips()
    -- Clear existing blips
    for _, blip in ipairs(zoneBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    zoneBlips = {}
    
    if not Config.ShowBlips then return end
    
    for _, zone in ipairs(Config.Zones) do
        -- Calculate center point from polygon
        local centerX, centerY, centerZ = 0, 0, 0
        for _, point in ipairs(zone.points) do
            centerX = centerX + point.x
            centerY = centerY + point.y
            centerZ = centerZ + point.z
        end
        centerX = centerX / #zone.points
        centerY = centerY / #zone.points
        centerZ = centerZ / #zone.points
        
        local center = vector3(centerX, centerY, centerZ)
        
        -- Create main blip at center
        local blip = AddBlipForCoord(center.x, center.y, center.z)
        SetBlipSprite(blip, zone.blipSprite or 618) -- Sand castle by default
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, zone.blipScale or 0.8)
        SetBlipColour(blip, zone.blipColor or 46)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(zone.label or "Treasure Zone")
        EndTextCommandSetBlipName(blip)
        table.insert(zoneBlips, blip)
        
        -- Create area outline for the zone by connecting the points with line blips
        if #zone.points >= 3 then
            -- Create a polygon outline using line blips between each point
            for i = 1, #zone.points do
                local currentPoint = zone.points[i]
                local nextPoint = zone.points[i+1]
                
                -- If we're at the last point, connect back to the first point
                if i == #zone.points then
                    nextPoint = zone.points[1]
                end
                
                -- Create area blip for this segment
                local areaBlip = AddBlipForArea(
                    (currentPoint.x + nextPoint.x) / 2,  -- Center point between the two vertices
                    (currentPoint.y + nextPoint.y) / 2, 
                    0.0,  -- Width - not used for polygon
                    0.0   -- Height - not used for polygon
                )
                
                -- Configure the area blip
                SetBlipRotation(areaBlip, 0)
                SetBlipColour(areaBlip, zone.blipColor or 46)
                SetBlipAlpha(areaBlip, 128)
                
                -- Use a more sophisticated method for polygon display
                SetBlipAsShortRange(areaBlip, true)
                SetBlipDisplay(areaBlip, 4)  -- Shows only on main map
                
                -- Store the blip for cleanup
                table.insert(zoneBlips, areaBlip)
            end
            
            -- Create an actual area blip that fills the zone
            -- Use the GTA native for polygon areas
            -- Create an array of points for the polygon
            local polygonPoints = {}
            for _, point in ipairs(zone.points) do
                table.insert(polygonPoints, point.x)
                table.insert(polygonPoints, point.y)
            end
            
            -- Note: For a true polygon representation, check if your game version supports BlipAddPolygon
            -- This native may not be available in all FiveM versions
            if _G.BlipAddPolygon then
                local polygonBlip = BlipAddPolygon(polygonPoints, zone.blipColor or 46, 128)
                table.insert(zoneBlips, polygonBlip)
            else
                -- Fallback: Add a translucent rectangular area approximation
                local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                for _, point in ipairs(zone.points) do
                    minX = math.min(minX, point.x)
                    minY = math.min(minY, point.y)
                    maxX = math.max(maxX, point.x)
                    maxY = math.max(maxY, point.y)
                end
                
                local width = maxX - minX
                local height = maxY - minY
                local centerX = minX + width/2
                local centerY = minY + height/2
                
                local areaBlip = AddBlipForArea(centerX, centerY, width, height)
                SetBlipRotation(areaBlip, 0)
                SetBlipColour(areaBlip, zone.blipColor or 46)
                SetBlipAlpha(areaBlip, 80)  -- More transparent
                table.insert(zoneBlips, areaBlip)
            end
        end
    end
end

-- Set up poly zones for treasure hunting areas
CreateThread(function()
    for i, zone in ipairs(Config.Zones) do
        local zoneName = "treasure_zone_" .. zone.name
        
        -- Set default value for allowRaking if not specified in config
        if zone.allowRaking == nil then
            zone.allowRaking = true -- Default to true if not specified
        end
        
        -- Add target zone
        if Config.TargetSystem == 'qb-target' then
            AddBoxZone(zoneName, zone.points, {
                options = {},
                distance = 10.0
            }, zone.minZ, zone.maxZ)
        end
        
        -- Create zone for metal detector logic
        local polyZone = PolyZone:Create(zone.points, {
            name = zoneName,
            minZ = zone.minZ,
            maxZ = zone.maxZ,
            debugPoly = Config.Debug and Config.ShowZones
        })
        
        if Config.Debug and Config.ShowZones then
            table.insert(debugZonePolys, polyZone)
        end
        
        polyZone:onPlayerInOut(function(isPointInside)
            if isPointInside then
                currentZone = zone
                local zoneInfo = 'You entered a treasure hunting area: ' .. zone.name
                if zone.allowRaking then
                    zoneInfo = zoneInfo .. ' (raking allowed)'
                end
                QBCore.Functions.Notify(zoneInfo, 'info')
            else
                if currentZone and currentZone.name == zone.name then
                    currentZone = nil
                    StopBeeping()
                    QBCore.Functions.Notify('You left the treasure hunting area: ' .. zone.name, 'info')
                end
            end
        end)
    end
    
    -- Create blips
    CreateZoneBlips()
end)

-- Helper function for displaying help text
function DisplayHelpTextThisFrame(text, beep)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentString(text or "Press ~INPUT_CONTEXT~ to dig")  -- Changed from AddTextComponentSubstringKeyboardDisplay
    EndTextCommandDisplayHelp(0, false, beep == true, -1)
end

-- Function to add dig option
function AddDigOption()
    if Config.UseThirdEye then
        -- Use third eye target system
        local options = {}
        
        if Config.TargetSystem == 'qb-target' then
            options = {
                options = {
                    {
                        type = "client",
                        event = "muffin_metaldetecting:client:digTreasure",
                        icon = "fas fa-shovel",
                        label = "Dig",
                        canInteract = function()
                            return isScanning and #(GetEntityCoords(PlayerPedId()) - treasurePos) <= Config.DigRadius
                        end
                    }
                },
                distance = 3.0
            }
        else -- ox_target
            options = {
                options = {
                    {
                        name = 'dig_treasure',
                        icon = 'fas fa-shovel',
                        label = 'Dig',
                        onSelect = function()
                            TriggerEvent("muffin_metaldetecting:client:digTreasure")
                        end,
                        canInteract = function(entity, distance, coords, name)
                            return isScanning and distance <= Config.DigRadius
                        end
                    }
                }
            }
        end
        
        AddCircleZone("treasure_dig", treasurePos, Config.DigRadius, options)
    else
        -- Use marker system with improved E key interaction
        CreateThread(function()
            local markerShown = true
            local interactionText = "Press ~INPUT_CONTEXT~ to dig"
            local interactionDistance = 1.5 -- Closer interaction distance for reliability
            
            while isScanning and markerShown do
                local playerPos = GetEntityCoords(PlayerPedId())
                local distance = #(playerPos - treasurePos)
                
                -- Always draw marker within dig radius
                if distance <= Config.DigRadius then
                    -- Draw marker
                    DrawMarker(
                        Config.MarkerType, 
                        treasurePos.x, treasurePos.y, treasurePos.z + 0.2, 
                        0.0, 0.0, 0.0, 
                        0.0, 0.0, 0.0, 
                        Config.MarkerScale.x, Config.MarkerScale.y, Config.MarkerScale.z, 
                        Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, Config.MarkerColor.a, 
                        false, true, 2, nil, nil, false
                    )
                    
                    -- Check for interaction - display help text when very close to the marker
                    if distance <= interactionDistance then
                        -- Show help text to dig
                        DisplayHelpText(interactionText)
                        
                        -- Check for E key press (input context)
                        if IsControlJustPressed(0, 38) then -- E key
                            markerShown = false
                            TriggerEvent("muffin_metaldetecting:client:digTreasure")
                            break
                        end
                    end
                end
                
                Wait(0) -- Using Wait(0) for responsive controls
            end
        end)
    end
    
    -- Debug visualization of dig area
    if Config.Debug then
        CreateThread(function()
            local startTime = GetGameTimer()
            while isScanning and GetGameTimer() - startTime < 10000 do
                DrawMarker(1, treasurePos.x, treasurePos.y, treasurePos.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                    Config.DigRadius * 2.0, Config.DigRadius * 2.0, 1.0, 0, 255, 0, 128, false, true, 2, nil, nil, false)
                Wait(0)
            end
        end)
    end
end

-- Helper function for displaying help text (improved)
function DisplayHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text) -- More reliable than AddTextComponentString
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Function to start metal detection
function StartMetalDetection()
    if cooldownActive then
        QBCore.Functions.Notify('The metal detector needs time to cool down', 'error')
        return
    end

    if not currentZone then
        QBCore.Functions.Notify('You need to be in a designated area to use the metal detector', 'error')
        return
    end
    
    if isScanning then
        StopMetalDetection()
        return
    end

    -- Record start time for tracking
    startTime = GetGameTimer()
    
    -- Start using metal detector
    isScanning = true
    
    -- Play metal detector animation
    TriggerEvent('animations:client:EmoteCommandStart', {Config.ScanEmote})
    
    -- Set cooldown
    cooldownActive = true
    SetTimeout(Config.Cooldown * 1000, function()
        cooldownActive = false
    end)
    
    -- Generate random treasure position that's guaranteed to be inside the current zone
    treasurePos = GenerateTreasurePosition()
    
    -- Start beeping logic
    StartBeeping()
    
    -- Debug blip if needed
    if Config.Debug then
        CreateTreasureBlip()
    end
    
    -- Add "Dig" option when close to treasure
    CreateThread(function()
        while isScanning do
            local playerPos = GetEntityCoords(PlayerPedId())
            local distance = #(playerPos - treasurePos)
            
            if distance <= Config.DigRadius then
                AddDigOption()
                break
            end
            Wait(1000)
        end
    end)
    
    -- Add cancel key listener
    CreateThread(function()
        while isScanning do
            -- Check for X key press to cancel
            if IsControlJustPressed(0, Config.CancelKey) then
                StopMetalDetection()
                QBCore.Functions.Notify('Metal detecting cancelled', 'info')
                break
            end
            Wait(0)
        end
    end)
    
    QBCore.Functions.Notify('You started scanning for treasures. Press X to cancel.', 'info')
end

-- Function to generate a treasure position within the current zone
function GenerateTreasurePosition()
    -- Maximum attempts to find a valid position
    local maxAttempts = 50
    local attempts = 0
    local foundValidPosition = false
    local position = nil
    
    -- Create a PolyZone object from the current zone points for easier point-in-poly testing
    local zonePolygon = PolyZone:Create(currentZone.points, {
        name = "temp_treasure_zone",
        minZ = currentZone.minZ,
        maxZ = currentZone.maxZ
    })
    
    while attempts < maxAttempts and not foundValidPosition do
        -- Get player position
        local playerPos = GetEntityCoords(PlayerPedId())
        
        -- Generate random position within treasure radius
        local randomAngle = math.random() * 2 * math.pi
        local randomDist = math.random(5, Config.TreasureRadius)
        
        local offsetX = randomDist * math.cos(randomAngle)
        local offsetY = randomDist * math.sin(randomAngle)
        
        local potentialPos = vector3(
            playerPos.x + offsetX,
            playerPos.y + offsetY,
            0.0
        )
        
        -- Get ground Z coordinate
        local groundZ = 0.0
        local found, zCoord = GetGroundZFor_3dCoord(potentialPos.x, potentialPos.y, 100.0, 0)
        if found then
            groundZ = zCoord
        end
        
        potentialPos = vector3(potentialPos.x, potentialPos.y, groundZ)
        
        -- Check if position is inside zone
        if zonePolygon:isPointInside(potentialPos) then
            position = potentialPos
            foundValidPosition = true
        end
        
        attempts = attempts + 1
    end
    
    -- If we couldn't find a valid position after max attempts, 
    -- fall back to a position close to the player but still in zone
    if not foundValidPosition then
        -- Find center of zone as fallback
        local centerX, centerY, centerZ = 0, 0, 0
        for _, point in ipairs(currentZone.points) do
            centerX = centerX + point.x
            centerY = centerY + point.y
            centerZ = centerZ + point.z
        end
        centerX = centerX / #currentZone.points
        centerY = centerY / #currentZone.points
        centerZ = centerZ / #currentZone.points
        
        -- Get ground Z for center
        local found, zCoord = GetGroundZFor_3dCoord(centerX, centerY, 100.0, 0)
        if found then
            centerZ = zCoord
        end
        
        position = vector3(centerX, centerY, centerZ)
        
        -- Let the player know
        QBCore.Functions.Notify('Treasure detection is having trouble. Try moving to a different area within the zone.', 'info')
    end
    
    -- Clean up the temporary zone
    zonePolygon:destroy()
    
    -- Return the position
    return position
end

-- Function to stop metal detection
function StopMetalDetection()
    if isScanning then
        isScanning = false
        StopBeeping()
        
        -- Calculate hunting time and send to server
        if startTime > 0 then
            local endTime = GetGameTimer()
            local sessionTime = math.floor((endTime - startTime) / 1000) -- Convert to seconds
            if sessionTime > 5 then -- Only track if they hunted for more than 5 seconds
                TriggerServerEvent('muffin_metaldetecting:server:trackTime', sessionTime)
            end
            startTime = 0
        end
        
        -- Stop animation
        TriggerEvent('animations:client:EmoteCommandStart', {"c"})
        
        -- Remove dig option if using third eye
        if Config.UseThirdEye then
            RemoveZone("treasure_dig")
        end
        
        -- Remove blip if exists
        if treasureBlip then
            RemoveBlip(treasureBlip)
            treasureBlip = nil
        end
        
        QBCore.Functions.Notify('You stopped scanning', 'info')
    end
end

-- Beeping logic based on distance to treasure
function StartBeeping()
    if beepLoop then return end
    
    beepLoop = true
    CreateThread(function()
        while beepLoop and isScanning and treasurePos do
            local playerPos = GetEntityCoords(PlayerPedId())
            local distance = #(playerPos - treasurePos)
            
            -- Calculate beep rate based on distance
            local beepRate = 0
            if distance <= Config.DigRadius then
                beepRate = Config.MaxBeepRate
            else
                -- Linear interpolation between min and max beep rates
                local distanceRange = Config.TreasureRadius - Config.DigRadius
                local distanceRatio = (distance - Config.DigRadius) / distanceRange
                beepRate = Config.MaxBeepRate + distanceRatio * (Config.MinBeepRate - Config.MaxBeepRate)
                beepRate = math.min(Config.MinBeepRate, math.max(Config.MaxBeepRate, beepRate))
            end
            
            -- Play beep sound
            PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
            
            -- Debug display
            if Config.Debug then
                DrawMarker(1, treasurePos.x, treasurePos.y, treasurePos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                    Config.DigRadius * 2.0, Config.DigRadius * 2.0, 1.0, 255, 0, 0, 128, false, true, 2, nil, nil, false)
            end
            
            Wait(beepRate * 1000)
        end
    end)
end

function StopBeeping()
    beepLoop = false
end

-- Debug function to create a blip at the treasure location
function CreateTreasureBlip()
    if treasureBlip then
        RemoveBlip(treasureBlip)
    end
    
    treasureBlip = AddBlipForCoord(treasurePos)
    SetBlipSprite(treasureBlip, 364)
    SetBlipColour(treasureBlip, 2)
    SetBlipScale(treasureBlip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Treasure")
    EndTextCommandSetBlipName(treasureBlip)
    
    -- Add radius indicator
    local radiusBlip = AddBlipForRadius(treasurePos.x, treasurePos.y, treasurePos.z, Config.DigRadius)
    SetBlipRotation(radiusBlip, 0)
    SetBlipColour(radiusBlip, 2)
    SetBlipAlpha(radiusBlip, 128)
    
    -- Store both blips with the same variable so they get cleaned up together
    local originalRemoveBlip = RemoveBlip
    local blipToRemove = treasureBlip
    treasureBlip = {
        mainBlip = treasureBlip,
        radiusBlip = radiusBlip
    }
    
    -- Override RemoveBlip for treasureBlip
    RemoveBlip = function(blip)
        if blip == treasureBlip then
            originalRemoveBlip(treasureBlip.mainBlip)
            originalRemoveBlip(treasureBlip.radiusBlip)
            treasureBlip = nil
            RemoveBlip = originalRemoveBlip
        else
            originalRemoveBlip(blip)
        end
    end
end

-- Event for digging up treasure
RegisterNetEvent('muffin_metaldetecting:client:digTreasure', function()
    if not isScanning or not treasurePos then return end
    
    local playerPos = GetEntityCoords(PlayerPedId())
    local distance = #(playerPos - treasurePos)
    
    if distance <= Config.DigRadius then
        -- Stop detecting
        StopBeeping()
        
        -- Calculate hunting time if this is the end of a session
        if startTime > 0 then
            local endTime = GetGameTimer()
            local sessionTime = math.floor((endTime - startTime) / 1000) -- Convert to seconds
            if sessionTime > 5 then -- Only track if they hunted for more than 5 seconds
                TriggerServerEvent('muffin_metaldetecting:server:trackTime', sessionTime)
            end
            startTime = 0
        end
        
        -- Start digging animation
        TriggerEvent('animations:client:EmoteCommandStart', {Config.DigEmote})
        
        -- Variable to track if digging was cancelled by X key
        local digCancelledByKey = false
        
        -- Add cancel key listener
        local cancelThread = CreateThread(function()
            while isScanning do
                -- Check for X key press to cancel
                if IsControlJustPressed(0, Config.CancelKey) then
                    TriggerEvent("progressbar:client:cancel")
                    digCancelledByKey = true
                    break
                end
                Wait(0)
            end
        end)
        
        -- Progress bar for digging
        QBCore.Functions.Progressbar("digging_treasure", "Digging...", Config.DigTime, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            -- Stop the cancel thread
            TerminateThread(cancelThread)
            
            -- Stop digging animation
            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
            
            -- Server event to give reward
            TriggerServerEvent('muffin_metaldetecting:server:giveTreasureReward')
            
            -- Clean up
            RemoveZone("treasure_dig")
            isScanning = false
            treasurePos = nil
            
            if treasureBlip then
                RemoveBlip(treasureBlip)
                treasureBlip = nil
            end
            
        end, function() -- Cancel
            -- Stop digging animation
            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
            if digCancelledByKey then
                QBCore.Functions.Notify('Digging cancelled', 'info')
            else
                QBCore.Functions.Notify('You stopped digging', 'error')
            end
            
            -- Clean up the thread if it's still running
            TerminateThread(cancelThread)
        end)
    end
end)

-- Helper function to safely terminate a thread
function TerminateThread(threadId)
    if threadId then
        Citizen.InvokeNative(0xDF7F5BE9150E47E4, threadId) -- Native to terminate thread
    end
end

-- Improved NUI callbacks
RegisterNUICallback('close', function(data, cb)
    CloseLeaderboard()
    cb({ok = true})
end)

function CloseLeaderboard()
    if not isLeaderboardOpen then return end
    isLeaderboardOpen = false
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "close"
    })
end

function OpenLeaderboard(leaderboardData, playerStats, playerId)
    if isLeaderboardOpen then return end
    isLeaderboardOpen = true
    
    -- Set NUI focus before showing the UI
    SetNuiFocus(true, true)
    
    -- Make sure we have valid data, even if empty
    leaderboardData = leaderboardData or {}
    playerStats = playerStats or {
        totalItems = 0,
        totalValue = 0,
        rareItems = 0,
        totalTime = 0,
        itemBreakdown = {}
    }
    
    SendNUIMessage({
        type = "open",
        leaderboard = leaderboardData,
        playerStats = playerStats,
        playerId = playerId
    })
end

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    CloseLeaderboard()
    cb('ok')
end)

-- Client event to open leaderboard
RegisterNetEvent('muffin_metaldetecting:client:openLeaderboard', function(leaderboardData, playerStats, playerId)
    OpenLeaderboard(leaderboardData, playerStats, playerId)
end)

-- Register command to open leaderboard - fixed version
RegisterCommand('detectingboard', function()
    -- Notify the user that the request is being processed
    QBCore.Functions.Notify('Loading leaderboard data...', 'primary')
    -- Request leaderboard data from the server
    TriggerServerEvent('muffin_metaldetecting:server:requestLeaderboard')
end, false)

-- Make sure this event handler is properly set up
RegisterNetEvent('muffin_metaldetecting:client:openLeaderboard')
AddEventHandler('muffin_metaldetecting:client:openLeaderboard', function(leaderboardData, playerStats, playerId)
    OpenLeaderboard(leaderboardData, playerStats, playerId)
end)

-- Modified treasure hunt events triggered by message in a bottle
RegisterNetEvent('muffin_metaldetecting:client:readTreasureMap', function()
    -- Remove any existing treasure marker
    if treasureBlip then
        RemoveBlip(treasureBlip)
        treasureBlip = nil
    end
    
    -- Select random treasure location from config
    local locations = Config.MessageBottle.treasureLocations
    local randomLocation = locations[math.random(#locations)]
    activeTreasureLocation = randomLocation
    
    -- Set GPS waypoint to treasure
    SetNewWaypoint(activeTreasureLocation.x, activeTreasureLocation.y)
    
    -- Create map blip
    treasureBlip = AddBlipForCoord(activeTreasureLocation.x, activeTreasureLocation.y, activeTreasureLocation.z)
    SetBlipSprite(treasureBlip, 364)  -- Treasure chest blip
    SetBlipColour(treasureBlip, 5)    -- Yellow color
    SetBlipScale(treasureBlip, 0.8)
    SetBlipAsShortRange(treasureBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Buried Treasure")
    EndTextCommandSetBlipName(treasureBlip)
    
    -- Add route to treasure
    SetBlipRoute(treasureBlip, true)
    SetBlipRouteColour(treasureBlip, 5)
    
    -- Notify player
    QBCore.Functions.Notify('You unrolled an old treasure map from the bottle!', 'success')
    QBCore.Functions.Notify('The location has been marked on your GPS.', 'primary')
    
    -- Start thread to check player distance to treasure
    CreateThread(function()
        isTreasureMarked = true
        
        while isTreasureMarked and activeTreasureLocation do
            -- Get player position
            local playerPos = GetEntityCoords(PlayerPedId())
            local treasurePos = vector3(activeTreasureLocation.x, activeTreasureLocation.y, activeTreasureLocation.z)
            local distance = #(playerPos - treasurePos)
            
            -- When close enough to treasure location
            if distance < 30.0 then
                -- Stop route
                SetBlipRoute(treasureBlip, false)
                
                -- Notify player when first arriving
                if distance < 25.0 and distance > 24.0 then
                    QBCore.Functions.Notify('You\'re getting close to the buried treasure!', 'primary')
                end
                
                -- Add dig interaction when very close
                if distance <= Config.MessageBottle.treasureRadius then
                    AddTreasureDigOption(treasurePos)
                    break
                end
            end
            
            Wait(1000)
        end
    end)
end)

-- Function to add treasure dig option
function AddTreasureDigOption(treasurePos)
    if Config.MessageBottle.useThirdEye then
        -- Use third eye target system
        local options = {}
        
        if Config.TargetSystem == 'qb-target' then
            options = {
                options = {
                    {
                        type = "client",
                        event = "muffin_metaldetecting:client:digBuriedTreasure",
                        icon = "fas fa-treasure-chest",
                        label = "Dig Buried Treasure",
                    }
                },
                distance = 3.0
            }
        else -- ox_target
            options = {
                options = {
                    {
                        name = 'dig_buried_treasure',
                        icon = 'fas fa-treasure-chest',
                        label = 'Dig Buried Treasure',
                        onSelect = function()
                            TriggerEvent("muffin_metaldetecting:client:digBuriedTreasure")
                        end,
                        canInteract = function(entity, distance, coords, name)
                            return distance <= Config.MessageBottle.treasureRadius
                        end
                    }
                }
            }
        end
        
        AddCircleZone("buried_treasure", treasurePos, Config.MessageBottle.treasureRadius, options)
    else
        -- Use marker system with improved E key interaction
        CreateThread(function()
            local markerShown = true
            local interactionText = "Press ~INPUT_CONTEXT~ to dig up buried treasure"
            local interactionDistance = 1.5 -- Closer interaction distance for reliability
            
            while isTreasureMarked and markerShown do
                local playerPos = GetEntityCoords(PlayerPedId())
                local distance = #(playerPos - treasurePos)
                
                -- Always draw marker within treasure radius
                if distance <= Config.MessageBottle.treasureRadius then
                    -- Draw marker (X marks the spot!)
                    DrawMarker(
                        20, -- X marker type
                        treasurePos.x, treasurePos.y, treasurePos.z + 0.2, 
                        0.0, 0.0, 0.0, 
                        0.0, 0.0, 0.0, 
                        0.5, 0.5, 0.5, -- Larger marker
                        255, 215, 0, 200, -- Gold color
                        true, true, 2, nil, nil, false
                    )
                    
                    -- Check for interaction
                    if distance <= interactionDistance then
                        -- Show help text to dig
                        DisplayHelpText(interactionText)
                        
                        -- Check for E key press (input context)
                        if IsControlJustPressed(0, 38) then -- E key
                            markerShown = false
                            TriggerEvent("muffin_metaldetecting:client:digBuriedTreasure")
                            break
                        end
                    end
                end
                
                Wait(0) -- Using Wait(0) for responsive controls
            end
        end)
    end
end

-- Event for digging up buried treasure
RegisterNetEvent('muffin_metaldetecting:client:digBuriedTreasure', function()
    if not isTreasureMarked or not activeTreasureLocation then return end
    
    local playerPos = GetEntityCoords(PlayerPedId())
    local treasurePos = vector3(activeTreasureLocation.x, activeTreasureLocation.y, activeTreasureLocation.z)
    local distance = #(playerPos - treasurePos)
    
    if distance <= Config.MessageBottle.treasureRadius then
        -- Start digging animation
        TriggerEvent('animations:client:EmoteCommandStart', {Config.DigEmote})
        
        -- Variable to track if digging was cancelled by X key
        local digCancelledByKey = false
        
        -- Add cancel key listener
        local cancelThread = CreateThread(function()
            while isTreasureMarked do
                -- Check for X key press to cancel
                if IsControlJustPressed(0, Config.CancelKey) then
                    TriggerEvent("progressbar:client:cancel")
                    digCancelledByKey = true
                    break
                end
                Wait(0)
            end
        end)
        
        -- Progress bar for digging
        QBCore.Functions.Progressbar("digging_buried_treasure", "Digging up buried treasure...", Config.MessageBottle.digTime, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            -- Stop the cancel thread
            TerminateThread(cancelThread)
            
            -- Stop digging animation
            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
            
            -- Server event to give special reward
            TriggerServerEvent('muffin_metaldetecting:server:digBuriedTreasure')
            
            -- Clean up
            if Config.MessageBottle.useThirdEye then
                RemoveZone("buried_treasure")
            end
            
            if treasureBlip then
                RemoveBlip(treasureBlip)
                treasureBlip = nil
            end
            
            isTreasureMarked = false
            activeTreasureLocation = nil
            
        end, function() -- Cancel
            -- Stop digging animation
            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
            if digCancelledByKey then
                QBCore.Functions.Notify('Digging cancelled', 'info')
            else
                QBCore.Functions.Notify('You stopped digging', 'error')
            end
            
            -- Clean up the thread if it's still running
            TerminateThread(cancelThread)
        end)
    end
end)

-- Clean up function - add this to your existing onResourceStop handler
-- Inside the onResourceStop event handler, add:
    if isTreasureMarked and treasureBlip then
        RemoveBlip(treasureBlip)
    end
    
    if Config.MessageBottle.useThirdEye then
        RemoveZone("buried_treasure")
    end

local QBCore = exports['qb-core']:GetCoreObject()
local creatingZone = false
local zonePoints = {}
local zoneObjects = {}
local lastPointTime = 0
local rmb_hold_start = 0

-- Start kitchen creation
RegisterCommand('createkitchen', function()
    if creatingZone then
        QBCore.Functions.Notify("You're already creating a kitchen!", "error")
        return
    end
    
    QBCore.Functions.TriggerCallback('danglr-kitchens:server:canCreateKitchen', function(canCreate)
        if not canCreate then
            QBCore.Functions.Notify("You don't have permission to create kitchens", "error")
            return
        end
        
        StartKitchenCreation()
    end)
end)

function StartKitchenCreation()
    creatingZone = true
    zonePoints = {}
    zoneObjects = {}
    
    QBCore.Functions.Notify("Kitchen creation started! Left Click to place points, Hold RMB for 4 seconds to finish", "success")
    QBCore.Functions.Notify("RMB once to remove last point", "primary")
    
    -- Enable noclip for flying
    TriggerEvent('qb-admin:client:ToggleNoClip')
    
    CreateThread(function()
        while creatingZone do
            Wait(0)
            
            -- Left click to add point
            if IsControlJustPressed(0, 24) then -- LEFT CLICK
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                
                table.insert(zonePoints, vector2(coords.x, coords.y))
                
                -- Spawn object at point
                local obj = CreateObject(GetHashKey('prop_mp_cone_02'), coords.x, coords.y, coords.z - 1.0, false, false, false)
                FreezeEntityPosition(obj, true)
                table.insert(zoneObjects, obj)
                
                QBCore.Functions.Notify("Point #" .. #zonePoints .. " added", "success")
                
                if Config.Debug then
                    print('^2[Kitchen Creator]^7 Point added: ' .. coords.x .. ', ' .. coords.y)
                end
            end
            
            -- Right click once to remove last point
            if IsControlJustPressed(0, 25) then -- RIGHT CLICK
                rmb_hold_start = GetGameTimer()
            end
            
            -- Right click release - check if it was a tap or hold
            if IsControlJustReleased(0, 25) then
                local hold_time = GetGameTimer() - rmb_hold_start
                
                if hold_time < 500 then -- Quick tap = remove last point
                    if #zonePoints > 0 then
                        table.remove(zonePoints, #zonePoints)
                        
                        if #zoneObjects > 0 then
                            local obj = table.remove(zoneObjects, #zoneObjects)
                            DeleteObject(obj)
                        end
                        
                        QBCore.Functions.Notify("Last point removed", "error")
                    end
                end
                
                rmb_hold_start = 0
            end
            
            -- Hold RMB for 4 seconds to finish
            if IsControlPressed(0, 25) and rmb_hold_start > 0 then
                local hold_time = GetGameTimer() - rmb_hold_start
                
                if hold_time >= Config.RemovePointHoldTime then
                    FinishKitchenCreation()
                    break
                end
            end
        end
    end)
end

function FinishKitchenCreation()
    if #zonePoints < 3 then
        QBCore.Functions.Notify("You need at least 3 points to create a kitchen", "error")
        CancelKitchenCreation()
        return
    end
    
    creatingZone = false
    
    -- Disable noclip
    TriggerEvent('qb-admin:client:ToggleNoClip')
    
    -- Open finish menu
    OpenFinishKitchenMenu()
end

function CancelKitchenCreation()
    creatingZone = false
    zonePoints = {}
    
    -- Clean up objects
    for _, obj in ipairs(zoneObjects) do
        DeleteObject(obj)
    end
    zoneObjects = {}
    
    -- Disable noclip
    TriggerEvent('qb-admin:client:ToggleNoClip')
    
    QBCore.Functions.Notify("Kitchen creation cancelled", "error")
end

function OpenFinishKitchenMenu()
    -- Get job list from QBCore
    QBCore.Functions.TriggerCallback('danglr-kitchens:server:getJobList', function(jobList)
        local input = lib.inputDialog('Finish Kitchen', {
            {
                type = 'input',
                label = 'Kitchen Name',
                description = 'Enter the name of this kitchen',
                required = true,
                min = 3,
                max = 50
            },
            {
                type = 'select',
                label = 'Job Lock',
                description = 'Select which job can use this kitchen',
                required = true,
                options = jobList
            }
        })
        
        if not input then
            -- Show confirmation menu
            local alert = lib.alertDialog({
                header = 'Cancel Kitchen?',
                content = 'Are you sure you want to cancel this kitchen?',
                centered = true,
                cancel = true
            })
            
            if alert == 'confirm' then
                CancelKitchenCreation()
            else
                OpenFinishKitchenMenu()
            end
            return
        end
        
        local kitchenName = input[1]
        local jobLock = input[2]
        
        -- Confirm kitchen creation
        local confirm = lib.alertDialog({
            header = 'Confirm Kitchen',
            content = 'Create kitchen "' .. kitchenName .. '" with job lock "' .. jobLock .. '"?',
            centered = true,
            cancel = true
        })
        
        if confirm == 'confirm' then
            -- Send to server
            TriggerServerEvent('danglr-kitchens:server:saveKitchen', {
                name = kitchenName,
                job = jobLock,
                points = zonePoints
            })
            
            -- Clean up objects
            for _, obj in ipairs(zoneObjects) do
                DeleteObject(obj)
            end
            zoneObjects = {}
            
            QBCore.Functions.Notify("Kitchen created successfully!", "success")
        else
            OpenFinishKitchenMenu()
        end
    end)
end

if Config.Debug then
    print('^2[danglr-kitchens]^7 Polyzone creator loaded')
end

-- Add command suggestion
TriggerEvent('chat:addSuggestion', '/createkitchen', 'Create a new kitchen zone')
TriggerEvent('chat:addSuggestion', '/createstation', 'Place a station in your kitchen')

if Config.Debug then
    print('^2[danglr-kitchens]^7 Polyzone creator loaded')
end

-- Add command suggestions
CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/createkitchen', 'Create a new kitchen zone')
end)


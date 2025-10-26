local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local currentKitchens = {}
local stationTargets = {}

-- Get player data
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    LoadKitchens()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- Load all kitchens and stations
function LoadKitchens()
    QBCore.Functions.TriggerCallback('danglr-kitchens:server:getKitchens', function(kitchens)
        currentKitchens = kitchens
        
        for _, kitchen in ipairs(kitchens) do
            CreateKitchenStations(kitchen)
        end
        
        if Config.Debug then
            print('^2[danglr-kitchens]^7 Loaded ' .. #kitchens .. ' kitchens')
        end
    end)
end

-- Create stations for a kitchen
function CreateKitchenStations(kitchen)
    if not kitchen.stations then return end
    
    for _, station in ipairs(kitchen.stations) do
        local stationId = 'kitchen_' .. kitchen.id .. '_station_' .. station.id
        local coords = json.decode(station.coords)
        local stationCoords = vector3(coords.x, coords.y, coords.z)
        
        exports['qb-target']:AddBoxZone(stationId, stationCoords, 1.0, 1.0, {
            name = stationId,
            heading = station.heading,
            debugPoly = Config.Debug,
            minZ = stationCoords.z - 1.0,
            maxZ = stationCoords.z + 1.5,
        }, {
            options = {
                {
                    type = "client",
                    event = "danglr-kitchens:client:useStation",
                    icon = "fas fa-hand-paper",
                    label = Config.StationLabels[station.type] or station.type,
                    kitchen = kitchen,
                    station = station,
                    canInteract = function()
                        -- Tray is accessible to everyone
                        if station.type == 'tray' then
                            return true
                        end
                        
                        -- Management requires boss grade
                        if station.type == 'management' then
                            return PlayerData.job and PlayerData.job.name == kitchen.job and PlayerData.job.grade.level >= Config.BossGrade
                        end
                        
                        -- All other stations require job
                        return PlayerData.job and PlayerData.job.name == kitchen.job
                    end,
                },
            },
            distance = 2.0
        })
        
        table.insert(stationTargets, stationId)
        
        if Config.Debug then
            print('^2[danglr-kitchens]^7 Created station: ' .. stationId)
        end
    end
end

-- Use station
RegisterNetEvent('danglr-kitchens:client:useStation', function(data)
    local station = data.station
    local kitchen = data.kitchen
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Using station type: ' .. station.type)
    end
    
    if station.type == 'storage' then
        OpenStorage(kitchen, station)
    elseif station.type == 'tray' then
        OpenTray(kitchen, station)
    elseif station.type == 'register' then
        OpenRegister(kitchen, station)
    elseif station.type == 'management' then
        OpenManagement(kitchen, station)
    elseif station.type == 'prep' then
        OpenPrepTable(kitchen, station)
    elseif station.type == 'grill' or station.type == 'fryer' or station.type == 'drink' then
        OpenCraftingStation(kitchen, station)
    elseif station.type == 'washhands' then
        WashHands()
    end
end)


-- Open storage (Fixed for qb-inventory)
function OpenStorage(kitchen, station)
    local stashId = 'kitchen_' .. kitchen.id .. '_storage_' .. station.id
    
    TriggerServerEvent('danglr-kitchens:server:openStash', stashId, 'storage')
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Opening storage: ' .. stashId)
    end
end

-- Open tray (Fixed for qb-inventory)
function OpenTray(kitchen, station)
    local stashId = 'kitchen_' .. kitchen.id .. '_tray_' .. station.id
    
    TriggerServerEvent('danglr-kitchens:server:openStash', stashId, 'tray')
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Opening tray: ' .. stashId)
    end
end


-- Open prep table
function OpenPrepTable(kitchen, station)
    local options = {}
    
    for _, prepItem in ipairs(Config.PrepItems) do
        table.insert(options, {
            title = prepItem.label,
            description = 'Use ' .. prepItem.amount .. 'x ' .. prepItem.item .. ' → Get ' .. prepItem.rewardAmount .. 'x ' .. prepItem.rewardItem,
            icon = 'knife',
            onSelect = function()
                PrepItem(prepItem)
            end
        })
    end
    
    lib.registerContext({
        id = 'prep_table_menu',
        title = 'Prep Table',
        options = options
    })
    
    lib.showContext('prep_table_menu')
end

-- Prep item
function PrepItem(prepItem)
    TriggerServerEvent('danglr-kitchens:server:prepItem', prepItem)
end

-- Start prepping animation
RegisterNetEvent('danglr-kitchens:client:startPrepping', function(prepItem)
    local ped = PlayerPedId()
    
    TaskStartScenarioInPlace(ped, 'PROP_HUMAN_PARKING_METER', 0, true)
    
    if lib.progressBar then
        lib.progressBar({
            duration = prepItem.duration,
            label = 'Preparing ' .. prepItem.label,
            useWhileDead = false,
            canCancel = false,
            disable = {
                move = true,
                car = true,
                combat = true,
            },
        })
    else
        Wait(prepItem.duration)
    end
    
    ClearPedTasksImmediately(ped)
    
    TriggerServerEvent('danglr-kitchens:server:finishPrepping', prepItem)
end)



-- Open register
function OpenRegister(kitchen, station)
    local players = QBCore.Functions.GetPlayersFromCoords(GetEntityCoords(PlayerPedId()), 3.0)
    
    if #players == 0 then
        QBCore.Functions.Notify("No customers nearby", "error")
        return
    end
    
    local input = lib.inputDialog('Charge Customer', {
        {
            type = 'number',
            label = 'Amount',
            description = 'Enter amount to charge',
            required = true,
            min = 1
        }
    })
    
    if not input then return end
    
    local amount = input[1]
    
    -- Get target player
    local options = {}
    for _, player in ipairs(players) do
        local playerId = GetPlayerServerId(player)
        local playerName = GetPlayerName(player)
        
        table.insert(options, {
            title = playerName,
            description = 'ID: ' .. playerId,
            onSelect = function()
                TriggerServerEvent('danglr-kitchens:server:chargeCustomer', playerId, amount, kitchen.job)
            end
        })
    end
    
    lib.registerContext({
        id = 'select_customer',
        title = 'Select Customer',
        options = options
    })
    
    lib.showContext('select_customer')
end

-- Open crafting station
function OpenCraftingStation(kitchen, station)
    QBCore.Functions.TriggerCallback('danglr-kitchens:server:getRecipes', function(recipes)
        local options = {}
        
        for _, recipe in ipairs(recipes) do
            local ingredients = json.decode(recipe.ingredients)
            local ingredientText = ""
            
            for i, ingredient in ipairs(ingredients) do
                if ingredient.item and ingredient.item ~= "" then
                    ingredientText = ingredientText .. ingredient.amount .. "x " .. ingredient.item
                    if i < #ingredients and ingredients[i+1].item and ingredients[i+1].item ~= "" then
                        ingredientText = ingredientText .. ", "
                    end
                end
            end
            
            table.insert(options, {
                title = recipe.name,
                description = 'Ingredients: ' .. ingredientText,
                icon = 'utensils',
                onSelect = function()
                    CraftItem(recipe, station)
                end
            })
        end
        
        if #options == 0 then
            QBCore.Functions.Notify("No recipes available for this station", "error")
            return
        end
        
        lib.registerContext({
            id = 'crafting_menu',
            title = Config.StationLabels[station.type],
            options = options
        })
        
        lib.showContext('crafting_menu')
    end, kitchen.id, station.type)
end

-- Craft item
function CraftItem(recipe, station)
    TriggerServerEvent('danglr-kitchens:server:craftItem', recipe, station.type)
end

-- Start crafting animation
RegisterNetEvent('danglr-kitchens:client:startCrafting', function(recipe, stationType)
    local ped = PlayerPedId()
    local scenario = Config.StationScenarios[stationType]
    
    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end
    
    if lib.progressBar then
        lib.progressBar({
            duration = 5000,
            label = 'Preparing ' .. recipe.name,
            useWhileDead = false,
            canCancel = false,
            disable = {
                move = true,
                car = true,
                combat = true,
            },
        })
    else
        Wait(5000)
    end
    
    ClearPedTasksImmediately(ped)
    
    TriggerServerEvent('danglr-kitchens:server:finishCrafting', recipe)
end)

-- Wash hands
function WashHands()
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, Config.StationScenarios['washhands'], 0, true)
    
    if lib.progressBar then
        lib.progressBar({
            duration = 3000,
            label = 'Washing hands',
            useWhileDead = false,
            canCancel = false,
        })
    else
        Wait(3000)
    end
    
    ClearPedTasksImmediately(ped)
    QBCore.Functions.Notify("Your hands are clean!", "success")
end

-- Open management menu (FIXED EXIT OPTION)
function OpenManagement(kitchen, station)
    lib.registerContext({
        id = 'management_menu',
        title = 'Management - ' .. kitchen.name,
        options = {
            {
                title = 'Finances',
                description = 'View and manage business finances',
                icon = 'dollar-sign',
                onSelect = function()
                    OpenFinances(kitchen)
                end
            },
            {
                title = 'Create Recipe',
                description = 'Create a new recipe',
                icon = 'plus',
                onSelect = function()
                    CreateRecipe(kitchen)
                end
            },
            {
                title = 'Edit Recipe',
                description = 'Edit an existing recipe',
                icon = 'edit',
                onSelect = function()
                    EditRecipeMenu(kitchen)
                end
            },
            {
                title = 'Delete Recipe',
                description = 'Delete a recipe',
                icon = 'trash',
                onSelect = function()
                    DeleteRecipeMenu(kitchen)
                end
            },
            {
                title = 'Hire Employee',
                description = 'Hire a nearby player',
                icon = 'user-plus',
                onSelect = function()
                    HireEmployee(kitchen)
                end
            },
            {
                title = 'Fire Employee',
                description = 'Fire an employee',
                icon = 'user-minus',
                onSelect = function()
                    FireEmployee(kitchen)
                end
            }
            -- Removed Exit Management option - menu closes automatically when you click outside
        }
    })
    
    lib.showContext('management_menu')
end


-- Open finances menu
function OpenFinances(kitchen)
    QBCore.Functions.TriggerCallback('danglr-kitchens:server:getSocietyMoney', function(balance)
        lib.registerContext({
            id = 'finances_menu',
            title = 'Finances - ' .. kitchen.name,
            menu = 'management_menu',
            options = {
                {
                    title = 'Business Balance',
                    description = '$' .. balance,
                    icon = 'money-bill-wave',
                    disabled = true
                },
                {
                    title = 'Withdraw Money',
                    description = 'Withdraw cash from business account',
                    icon = 'hand-holding-dollar',
                    onSelect = function()
                        WithdrawMoney(kitchen)
                    end
                },
                {
                    title = 'Deposit Money',
                    description = 'Deposit cash to business account',
                    icon = 'piggy-bank',
                    onSelect = function()
                        DepositMoney(kitchen)
                    end
                },
                {
                    title = 'Back',
                    description = 'Return to management menu',
                    icon = 'arrow-left',
                    menu = 'management_menu'
                }
            }
        })
        
        lib.showContext('finances_menu')
    end, kitchen.job)
end

-- Withdraw money
function WithdrawMoney(kitchen)
    local input = lib.inputDialog('Withdraw Money', {
        {
            type = 'number',
            label = 'Amount',
            description = 'Enter amount to withdraw',
            required = true,
            min = 1
        }
    })
    
    if not input then return end
    
    local amount = input[1]
    
    TriggerServerEvent('danglr-kitchens:server:withdrawMoney', kitchen.job, amount)
    
    -- Refresh finances menu after withdrawal
    Wait(500)
    OpenFinances(kitchen)
end

-- Deposit money
function DepositMoney(kitchen)
    local input = lib.inputDialog('Deposit Money', {
        {
            type = 'number',
            label = 'Amount',
            description = 'Enter amount to deposit',
            required = true,
            min = 1
        }
    })
    
    if not input then return end
    
    local amount = input[1]
    
    TriggerServerEvent('danglr-kitchens:server:depositMoney', kitchen.job, amount)
    
    -- Refresh finances menu after deposit
    Wait(500)
    OpenFinances(kitchen)
end

-- Hire employee
function HireEmployee(kitchen)
    local players = QBCore.Functions.GetPlayersFromCoords(GetEntityCoords(PlayerPedId()), 5.0)
    
    if #players == 0 then
        QBCore.Functions.Notify("No players nearby to hire", "error")
        return
    end
    
    local options = {}
    for _, player in ipairs(players) do
        local playerId = GetPlayerServerId(player)
        local playerName = GetPlayerName(player)
        
        table.insert(options, {
            title = playerName,
            description = 'ID: ' .. playerId,
            icon = 'user',
            onSelect = function()
                -- Ask for grade
                local input = lib.inputDialog('Hire ' .. playerName, {
                    {
                        type = 'number',
                        label = 'Grade Level',
                        description = 'Enter grade (0-' .. (Config.BossGrade - 1) .. ')',
                        required = true,
                        min = 0,
                        max = Config.BossGrade - 1,
                        default = 0
                    }
                })
                
                if not input then return end
                
                TriggerServerEvent('danglr-kitchens:server:hireEmployee', playerId, kitchen.job, input[1])
            end
        })
    end
    
    lib.registerContext({
        id = 'hire_employee_menu',
        title = 'Select Player to Hire',
        menu = 'management_menu',
        options = options
    })
    
    lib.showContext('hire_employee_menu')
end

-- Fire employee
function FireEmployee(kitchen)
    QBCore.Functions.TriggerCallback('danglr-kitchens:server:getEmployees', function(employees)
        if #employees == 0 then
            QBCore.Functions.Notify("No employees to fire", "error")
            return
        end
        
        local options = {}
        for _, employee in ipairs(employees) do
            table.insert(options, {
                title = employee.name,
                description = 'Citizen ID: ' .. employee.citizenid .. ' | Grade: ' .. employee.grade,
                icon = 'user',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = 'Fire Employee',
                        content = 'Are you sure you want to fire ' .. employee.name .. '?',
                        centered = true,
                        cancel = true
                    })
                    
                    if alert == 'confirm' then
                        TriggerServerEvent('danglr-kitchens:server:fireEmployee', employee.citizenid, kitchen.job)
                    end
                end
            })
        end
        
        lib.registerContext({
            id = 'fire_employee_menu',
            title = 'Select Employee to Fire',
            menu = 'management_menu',
            options = options
        })
        
        lib.showContext('fire_employee_menu')
    end, kitchen.job)
end

-- Create recipe (Fixed validation)
function CreateRecipe(kitchen)
    local input = lib.inputDialog('Create Recipe', {
        {
            type = 'input',
            label = 'Name of Food/Drink',
            description = 'Enter the item name',
            required = true
        },
        {
            type = 'checkbox',
            label = 'Is Food',
        },
        {
            type = 'checkbox',
            label = 'Is Drink',
        },
        {
            type = 'input',
            label = 'Ingredient 1',
            description = 'Item name from shared items',
        },
        {
            type = 'number',
            label = 'Ingredient 1 Amount',
            default = 0,
            min = 0
        },
        {
            type = 'input',
            label = 'Ingredient 2',
        },
        {
            type = 'number',
            label = 'Ingredient 2 Amount',
            default = 0,
            min = 0
        },
        {
            type = 'input',
            label = 'Ingredient 3',
        },
        {
            type = 'number',
            label = 'Ingredient 3 Amount',
            default = 0,
            min = 0
        },
        {
            type = 'input',
            label = 'Ingredient 4',
        },
        {
            type = 'number',
            label = 'Ingredient 4 Amount',
            default = 0,
            min = 0
        },
        {
            type = 'input',
            label = 'Ingredient 5',
        },
        {
            type = 'number',
            label = 'Ingredient 5 Amount',
            default = 0,
            min = 0
        },
        {
            type = 'input',
            label = 'Ingredient 6',
        },
        {
            type = 'number',
            label = 'Ingredient 6 Amount',
            default = 0,
            min = 0
        },
        {
            type = 'select',
            label = 'Station Type',
            description = 'Where can this be crafted?',
            required = true,
            options = {
                {value = 'grill', label = 'Grill (Food Only)'},
                {value = 'fryer', label = 'Fryer (Food Only)'},
                {value = 'drink', label = 'Drink Machine (Drinks Only)'}
            }
        },
        {
            type = 'number',
            label = 'Output Amount',
            description = 'How many items to receive',
            default = 1,
            min = 1,
            max = 10,
            required = true
        }
    })
    
    if not input then return end
    
    local recipeName = input[1]
    local isFood = input[2] or false
    local isDrink = input[3] or false
    local stationType = input[17]
    local outputAmount = tonumber(input[18]) or 1
    
    -- Validate food/drink vs station type
    if (isFood and stationType == 'drink') or (isDrink and (stationType == 'grill' or stationType == 'fryer')) then
        QBCore.Functions.Notify("Station type doesn't match food/drink selection!", "error")
        return
    end
    
    -- Build ingredients table (skip empty ones) - FIXED
    local ingredients = {}
    for i = 1, 6 do
        local itemName = input[3 + (i-1)*2]
        local itemAmount = tonumber(input[4 + (i-1)*2])
        
        -- Check if both item name exists AND amount is greater than 0
        if itemName and itemName ~= "" and itemName ~= nil and itemAmount and itemAmount > 0 then
            table.insert(ingredients, {
                item = itemName,
                amount = itemAmount
            })
        end
    end
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Recipe ingredients parsed:')
        for idx, ing in ipairs(ingredients) do
            print('  ' .. idx .. ': ' .. ing.item .. ' x' .. ing.amount)
        end
    end
    
    if #ingredients == 0 then
        QBCore.Functions.Notify("You must add at least one ingredient!", "error")
        return
    end
    
    -- Send to server
    TriggerServerEvent('danglr-kitchens:server:createRecipe', {
        kitchen_id = kitchen.id,
        name = recipeName,
        is_food = isFood,
        is_drink = isDrink,
        station_type = stationType,
        ingredients = ingredients,
        output_amount = outputAmount
    })
end



-- Edit recipe menu
function EditRecipeMenu(kitchen)
    QBCore.Functions.TriggerCallback('danglr-kitchens:server:getAllRecipes', function(recipes)
        local options = {}
        
        for _, recipe in ipairs(recipes) do
            table.insert(options, {
                title = recipe.name,
                description = 'Station: ' .. recipe.station_type,
                icon = 'edit',
                onSelect = function()
                    EditRecipe(kitchen, recipe)
                end
            })
        end
        
        if #options == 0 then
            QBCore.Functions.Notify("No recipes to edit", "error")
            return
        end
        
        lib.registerContext({
            id = 'edit_recipe_menu',
            title = 'Edit Recipe',
            menu = 'management_menu',
            options = options
        })
        
        lib.showContext('edit_recipe_menu')
    end, kitchen.id)
end

-- Edit recipe (Fixed validation)
function EditRecipe(kitchen, recipe)
    local existingIngredients = json.decode(recipe.ingredients)
    
    local input = lib.inputDialog('Edit Recipe', {
        {
            type = 'input',
            label = 'Name of Food/Drink',
            default = recipe.name,
            required = true
        },
        {
            type = 'checkbox',
            label = 'Is Food',
            checked = recipe.is_food == 1
        },
        {
            type = 'checkbox',
            label = 'Is Drink',
            checked = recipe.is_drink == 1
        },
        {
            type = 'input',
            label = 'Ingredient 1',
            default = existingIngredients[1] and existingIngredients[1].item or nil
        },
        {
            type = 'number',
            label = 'Ingredient 1 Amount',
            default = existingIngredients[1] and existingIngredients[1].amount or 0,
            min = 0
        },
        {
            type = 'input',
            label = 'Ingredient 2',
            default = existingIngredients[2] and existingIngredients[2].item or nil
        },
        {
            type = 'number',
            label = 'Ingredient 2 Amount',
            default = existingIngredients[2] and existingIngredients[2].amount or 0,
            min = 0
        },
        {
            type = 'input',
            label = 'Ingredient 3',
            default = existingIngredients[3] and existingIngredients[3].item or nil
        },
        {
            type = 'number',
            label = 'Ingredient 3 Amount',
            default = existingIngredients[3] and existingIngredients[3].amount or 0,
            min = 0
        },
        {
            type = 'input',
            label = 'Ingredient 4',
            default = existingIngredients[4] and existingIngredients[4].item or nil
        },
        {
            type = 'number',
            label = 'Ingredient 4 Amount',
            default = existingIngredients[4] and existingIngredients[4].amount or 0,
            min = 0
        },
        {
            type = 'input',
            label = 'Ingredient 5',
            default = existingIngredients[5] and existingIngredients[5].item or nil
        },
        {
            type = 'number',
            label = 'Ingredient 5 Amount',
            default = existingIngredients[5] and existingIngredients[5].amount or 0,
            min = 0
        },
        {
            type = 'input',
            label = 'Ingredient 6',
            default = existingIngredients[6] and existingIngredients[6].item or nil
        },
        {
            type = 'number',
            label = 'Ingredient 6 Amount',
            default = existingIngredients[6] and existingIngredients[6].amount or 0,
            min = 0
        },
        {
            type = 'select',
            label = 'Station Type',
            default = recipe.station_type,
            required = true,
            options = {
                {value = 'grill', label = 'Grill (Food Only)'},
                {value = 'fryer', label = 'Fryer (Food Only)'},
                {value = 'drink', label = 'Drink Machine (Drinks Only)'}
            }
        },
        {
            type = 'number',
            label = 'Output Amount',
            default = recipe.output_amount,
            min = 1,
            max = 10
        }
    })
    
    if not input then return end
    
    local recipeName = input[1]
    local isFood = input[2] or false
    local isDrink = input[3] or false
    local stationType = input[17]
    local outputAmount = tonumber(input[18]) or 1
    
    -- Validate
    if (isFood and stationType == 'drink') or (isDrink and (stationType == 'grill' or stationType == 'fryer')) then
        QBCore.Functions.Notify("Station type doesn't match food/drink selection!", "error")
        return
    end
    
    -- Build ingredients (skip empty ones) - FIXED
    local ingredients = {}
    for i = 1, 6 do
        local itemName = input[3 + (i-1)*2]
        local itemAmount = tonumber(input[4 + (i-1)*2])
        
        -- Check if both item name exists AND amount is greater than 0
        if itemName and itemName ~= "" and itemName ~= nil and itemAmount and itemAmount > 0 then
            table.insert(ingredients, {
                item = itemName,
                amount = itemAmount
            })
        end
    end
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Recipe ingredients parsed:')
        for idx, ing in ipairs(ingredients) do
            print('  ' .. idx .. ': ' .. ing.item .. ' x' .. ing.amount)
        end
    end
    
    if #ingredients == 0 then
        QBCore.Functions.Notify("You must add at least one ingredient!", "error")
        return
    end
    
    -- Send to server
    TriggerServerEvent('danglr-kitchens:server:updateRecipe', {
        id = recipe.id,
        kitchen_id = kitchen.id,
        name = recipeName,
        is_food = isFood,
        is_drink = isDrink,
        station_type = stationType,
        ingredients = ingredients,
        output_amount = outputAmount
    })
end

-- Delete recipe menu
function DeleteRecipeMenu(kitchen)
    QBCore.Functions.TriggerCallback('danglr-kitchens:server:getAllRecipes', function(recipes)
        local options = {}
        
        for _, recipe in ipairs(recipes) do
            table.insert(options, {
                title = recipe.name,
                description = 'Station: ' .. recipe.station_type,
                icon = 'trash',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = 'Delete Recipe',
                        content = 'Are you sure you want to delete "' .. recipe.name .. '"?',
                        centered = true,
                        cancel = true
                    })
                    
                    if alert == 'confirm' then
                        TriggerServerEvent('danglr-kitchens:server:deleteRecipe', recipe.id)
                    end
                end
            })
        end
        
        if #options == 0 then
            QBCore.Functions.Notify("No recipes to delete", "error")
            return
        end
        
        lib.registerContext({
            id = 'delete_recipe_menu',
            title = 'Delete Recipe',
            menu = 'management_menu',
            options = options
        })
        
        lib.showContext('delete_recipe_menu')
    end, kitchen.id)
end

-- Create station command
RegisterCommand('createstation', function()
    -- Check if player is in a kitchen zone
    QBCore.Functions.TriggerCallback('danglr-kitchens:server:getPlayerKitchen', function(kitchen)
        if not kitchen then
            QBCore.Functions.Notify("You must be inside a kitchen to create stations", "error")
            return
        end
        
        -- Check permissions
        if not (PlayerData.job and PlayerData.job.name == kitchen.job and PlayerData.job.grade.level >= Config.BossGrade) then
            QBCore.Functions.Notify("You must be the boss to create stations", "error")
            return
        end
        
        -- Open station selection menu
        lib.registerContext({
            id = 'create_station_menu',
            title = 'Create Station - ' .. kitchen.name,
            options = {
                {
                    title = 'Grill',
                    description = 'Place a grill station',
                    icon = 'fire',
                    onSelect = function()
                        PlaceStation(kitchen, 'grill')
                    end
                },
                {
                    title = 'Fryer',
                    description = 'Place a fryer station',
                    icon = 'fire-burner',
                    onSelect = function()
                        PlaceStation(kitchen, 'fryer')
                    end
                },
                {
                    title = 'Wash Hands',
                    description = 'Place a hand washing station',
                    icon = 'hands-wash',
                    onSelect = function()
                        PlaceStation(kitchen, 'washhands')
                    end
                },
                {
                    title = 'Prep Food',
                    description = 'Place a prep station',
                    icon = 'utensils',
                    onSelect = function()
                        PlaceStation(kitchen, 'prep')
                    end
                },
                {
                    title = 'Storage',
                    description = 'Place a storage station',
                    icon = 'box',
                    onSelect = function()
                        PlaceStation(kitchen, 'storage')
                    end
                },
                {
                    title = 'Drink Machine',
                    description = 'Place a drink machine',
                    icon = 'wine-glass',
                    onSelect = function()
                        PlaceStation(kitchen, 'drink')
                    end
                },
                {
                    title = 'Tray',
                    description = 'Place a food tray',
                    icon = 'box-open',
                    onSelect = function()
                        PlaceStation(kitchen, 'tray')
                    end
                },
                {
                    title = 'Register',
                    description = 'Place a register',
                    icon = 'cash-register',
                    onSelect = function()
                        PlaceStation(kitchen, 'register')
                    end
                },
                {
                    title = 'Management',
                    description = 'Place a management station (Boss Only)',
                    icon = 'user-tie',
                    onSelect = function()
                        PlaceStation(kitchen, 'management')
                    end
                }
            }
        })
        
        lib.showContext('create_station_menu')
    end)
end)

-- Delete station command (NEW)
RegisterCommand('deletestation', function()
    QBCore.Functions.TriggerCallback('danglr-kitchens:server:getPlayerKitchen', function(kitchen)
        if not kitchen then
            QBCore.Functions.Notify("You must be inside a kitchen to delete stations", "error")
            return
        end
        
        -- Check permissions
        if not (PlayerData.job and PlayerData.job.name == kitchen.job and PlayerData.job.grade.level >= Config.BossGrade) then
            QBCore.Functions.Notify("You must be the boss to delete stations", "error")
            return
        end
        
        -- Find closest station
        local playerCoords = GetEntityCoords(PlayerPedId())
        local closestStation = nil
        local closestDistance = 999999
        
        for _, station in ipairs(kitchen.stations) do
            local coords = json.decode(station.coords)
            local stationCoords = vector3(coords.x, coords.y, coords.z)
            local distance = #(playerCoords - stationCoords)
            
            if distance < closestDistance then
                closestDistance = distance
                closestStation = station
            end
        end
        
        if not closestStation then
            QBCore.Functions.Notify("No stations found nearby", "error")
            return
        end
        
        if closestDistance > 3.0 then
            QBCore.Functions.Notify("You're too far from any station", "error")
            return
        end
        
        -- Show confirmation
        local stationLabel = Config.StationLabels[closestStation.type] or closestStation.type
        
        local alert = lib.alertDialog({
            header = 'Delete Station',
            content = 'Are you sure you want to delete ' .. stationLabel .. '?',
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Delete',
                cancel = 'Cancel'
            }
        })
        
        if alert == 'confirm' then
            TriggerServerEvent('danglr-kitchens:server:deleteStation', closestStation.id)
        end
    end)
end)

-- Place station
function PlaceStation(kitchen, stationType)
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local playerHeading = GetEntityHeading(ped)
    
    -- Calculate placement position (1.3 units in front at hip height)
    local forwardVector = GetEntityForwardVector(ped)
    local placementCoords = vector3(
        playerCoords.x + (forwardVector.x * Config.PlacementDistance),
        playerCoords.y + (forwardVector.y * Config.PlacementDistance),
        playerCoords.z - 1.0  -- Hip height
    )
    
    -- Create vector4 with heading
    local stationVector4 = vector4(placementCoords.x, placementCoords.y, placementCoords.z, playerHeading)
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Placing station at: ' .. placementCoords.x .. ', ' .. placementCoords.y .. ', ' .. placementCoords.z .. ' | Heading: ' .. playerHeading)
    end
    
    -- Send to server
    TriggerServerEvent('danglr-kitchens:server:createStation', {
        kitchen_id = kitchen.id,
        type = stationType,
        coords = json.encode({x = stationVector4.x, y = stationVector4.y, z = stationVector4.z}),
        heading = stationVector4.w
    })
end

-- Reload stations after creating new one
RegisterNetEvent('danglr-kitchens:client:reloadStations', function()
    -- Remove all existing targets
    for _, targetId in ipairs(stationTargets) do
        exports['qb-target']:RemoveZone(targetId)
    end
    stationTargets = {}
    
    -- Reload kitchens
    LoadKitchens()
end)

-- Add command suggestions
CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/createstation', 'Place a station in your kitchen')
    TriggerEvent('chat:addSuggestion', '/deletestation', 'Delete the closest station to you')
end)

if Config.Debug then
    print('^2[danglr-kitchens]^7 Client main.lua loaded')
end


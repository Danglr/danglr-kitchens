local QBCore = exports['qb-core']:GetCoreObject()


local QBCore = exports['qb-core']:GetCoreObject()
local Stashes = {}

-- Open stash event (alternative method)
RegisterNetEvent('danglr-kitchens:server:openStash', function(stashId, stashType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local maxWeight = stashType == 'storage' and Config.StorageMaxWeight or Config.TrayMaxWeight
    local slots = stashType == 'storage' and Config.StorageSlots or Config.TraySlots
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Opening ' .. stashType .. ': ' .. stashId .. ' | Slots: ' .. slots .. ' | Weight: ' .. maxWeight)
    end
    
    exports['qb-inventory']:OpenInventory(src, stashId, {
        maxweight = maxWeight,
        slots = slots
    })
end)


-- Get all kitchens with their stations
QBCore.Functions.CreateCallback('danglr-kitchens:server:getKitchens', function(source, cb)
    local result = MySQL.query.await('SELECT * FROM kitchens')
    
    for i, kitchen in ipairs(result) do
        local stations = MySQL.query.await('SELECT * FROM kitchen_stations WHERE kitchen_id = ?', {kitchen.id})
        result[i].stations = stations
    end
    
    cb(result)
end)

-- Check if player can create kitchen
QBCore.Functions.CreateCallback('danglr-kitchens:server:canCreateKitchen', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if Config.AdminOnlyKitchen then
        cb(QBCore.Functions.HasPermission(source, 'admin'))
    else
        cb(true)
    end
end)

-- Create kitchen
RegisterNetEvent('danglr-kitchens:server:createKitchen', function(kitchenData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Insert kitchen into database
    local result = MySQL.insert.await('INSERT INTO kitchens (name, job, polyzone) VALUES (?, ?, ?)', {
        kitchenData.name,
        kitchenData.job,
        kitchenData.polyzone
    })
    
    if result then
        TriggerClientEvent('QBCore:Notify', src, 'Kitchen created successfully!', 'success')
        TriggerClientEvent('danglr-kitchens:client:reloadStations', -1)
        
        if Config.Debug then
            print('^2[danglr-kitchens]^7 Kitchen created: ' .. kitchenData.name)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to create kitchen', 'error')
    end
end)

-- Get player's current kitchen
QBCore.Functions.CreateCallback('danglr-kitchens:server:getPlayerKitchen', function(source, cb)
    local result = MySQL.query.await('SELECT * FROM kitchens')
    
    for _, kitchen in ipairs(result) do
        local stations = MySQL.query.await('SELECT * FROM kitchen_stations WHERE kitchen_id = ?', {kitchen.id})
        kitchen.stations = stations
        cb(kitchen)
        return
    end
    
    cb(nil)
end)

-- Create station (simplified - stashes created on-demand)
RegisterNetEvent('danglr-kitchens:server:createStation', function(stationData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local result = MySQL.insert.await('INSERT INTO kitchen_stations (kitchen_id, type, coords, heading) VALUES (?, ?, ?, ?)', {
        stationData.kitchen_id,
        stationData.type,
        stationData.coords,
        stationData.heading
    })
    
    if result then
        TriggerClientEvent('QBCore:Notify', src, 'Station created successfully!', 'success')
        TriggerClientEvent('danglr-kitchens:client:reloadStations', -1)
        
        if Config.Debug then
            print('^2[danglr-kitchens]^7 Station created: ' .. stationData.type)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to create station', 'error')
    end
end)



-- Delete station
RegisterNetEvent('danglr-kitchens:server:deleteStation', function(stationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local result = MySQL.query.await('DELETE FROM kitchen_stations WHERE id = ?', {stationId})
    
    if result then
        TriggerClientEvent('QBCore:Notify', src, 'Station deleted successfully!', 'success')
        TriggerClientEvent('danglr-kitchens:client:reloadStations', -1)
        
        if Config.Debug then
            print('^2[danglr-kitchens]^7 Station deleted: ' .. stationId)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to delete station', 'error')
    end
end)

-- Get recipes for kitchen
QBCore.Functions.CreateCallback('danglr-kitchens:server:getRecipes', function(source, cb, kitchenId, stationType)
    local result = MySQL.query.await('SELECT * FROM kitchen_recipes WHERE kitchen_id = ? AND station_type = ?', {
        kitchenId,
        stationType
    })
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Fetching recipes for kitchen ' .. kitchenId .. ' and station type: ' .. stationType)
        print('^2[danglr-kitchens]^7 Found ' .. #result .. ' recipes')
        
        for _, recipe in ipairs(result) do
            print('^2[danglr-kitchens]^7 Recipe: ' .. recipe.name .. ' | Station: ' .. recipe.station_type)
        end
    end
    
    cb(result)
end)

-- Get all recipes for kitchen
QBCore.Functions.CreateCallback('danglr-kitchens:server:getAllRecipes', function(source, cb, kitchenId)
    local result = MySQL.query.await('SELECT * FROM kitchen_recipes WHERE kitchen_id = ?', {kitchenId})
    cb(result)
end)

-- Create recipe
RegisterNetEvent('danglr-kitchens:server:createRecipe', function(recipeData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Creating recipe:')
        print('  Name: ' .. recipeData.name)
        print('  Kitchen ID: ' .. recipeData.kitchen_id)
        print('  Station Type: ' .. recipeData.station_type)
        print('  Is Food: ' .. tostring(recipeData.is_food))
        print('  Is Drink: ' .. tostring(recipeData.is_drink))
        print('  Ingredients: ' .. json.encode(recipeData.ingredients))
        print('  Output Amount: ' .. recipeData.output_amount)
    end
    
    local result = MySQL.insert.await('INSERT INTO kitchen_recipes (kitchen_id, name, is_food, is_drink, station_type, ingredients, output_amount) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        recipeData.kitchen_id,
        recipeData.name,
        recipeData.is_food,
        recipeData.is_drink,
        recipeData.station_type,
        json.encode(recipeData.ingredients),
        recipeData.output_amount
    })
    
    if result then
        TriggerClientEvent('QBCore:Notify', src, 'Recipe created successfully!', 'success')
        
        if Config.Debug then
            print('^2[danglr-kitchens]^7 Recipe created successfully with ID: ' .. result)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to create recipe', 'error')
        
        if Config.Debug then
            print('^1[danglr-kitchens ERROR]^7 Failed to insert recipe into database')
        end
    end
end)

-- Update recipe
RegisterNetEvent('danglr-kitchens:server:updateRecipe', function(recipeData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local result = MySQL.query.await('UPDATE kitchen_recipes SET name = ?, is_food = ?, is_drink = ?, station_type = ?, ingredients = ?, output_amount = ? WHERE id = ?', {
        recipeData.name,
        recipeData.is_food,
        recipeData.is_drink,
        recipeData.station_type,
        json.encode(recipeData.ingredients),
        recipeData.output_amount,
        recipeData.id
    })
    
    if result then
        TriggerClientEvent('QBCore:Notify', src, 'Recipe updated successfully!', 'success')
        
        if Config.Debug then
            print('^2[danglr-kitchens]^7 Recipe updated: ' .. recipeData.name)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to update recipe', 'error')
    end
end)

-- Delete recipe
RegisterNetEvent('danglr-kitchens:server:deleteRecipe', function(recipeId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local result = MySQL.query.await('DELETE FROM kitchen_recipes WHERE id = ?', {recipeId})
    
    if result then
        TriggerClientEvent('QBCore:Notify', src, 'Recipe deleted successfully!', 'success')
        
        if Config.Debug then
            print('^2[danglr-kitchens]^7 Recipe deleted: ' .. recipeId)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to delete recipe', 'error')
    end
end)

-- Craft item
RegisterNetEvent('danglr-kitchens:server:craftItem', function(recipe, stationType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local ingredients = json.decode(recipe.ingredients)
    
    -- Check if player has all ingredients
    for _, ingredient in ipairs(ingredients) do
        if ingredient.item and ingredient.item ~= "" then
            local hasItem = Player.Functions.GetItemByName(ingredient.item)
            if not hasItem or hasItem.amount < ingredient.amount then
                TriggerClientEvent('QBCore:Notify', src, 'You don\'t have enough ' .. ingredient.item, 'error')
                return
            end
        end
    end
    
    -- Start crafting
    TriggerClientEvent('danglr-kitchens:client:startCrafting', src, recipe, stationType)
end)

-- Finish crafting
RegisterNetEvent('danglr-kitchens:server:finishCrafting', function(recipe)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local ingredients = json.decode(recipe.ingredients)
    
    -- Remove ingredients
    for _, ingredient in ipairs(ingredients) do
        if ingredient.item and ingredient.item ~= "" then
            Player.Functions.RemoveItem(ingredient.item, ingredient.amount)
        end
    end
    
    -- Give output item
    Player.Functions.AddItem(recipe.name, recipe.output_amount)
    
    TriggerClientEvent('QBCore:Notify', src, 'You made ' .. recipe.output_amount .. 'x ' .. recipe.name, 'success')
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 ' .. GetPlayerName(src) .. ' crafted: ' .. recipe.name)
    end
end)

-- Charge customer (Fixed - using amount column)
RegisterNetEvent('danglr-kitchens:server:chargeCustomer', function(targetId, amount, society)
    local src = source
    local Employee = QBCore.Functions.GetPlayer(src)
    local Customer = QBCore.Functions.GetPlayer(targetId)
    
    if not Employee or not Customer then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        return
    end
    
    -- Check if customer has enough money
    local customerMoney = Customer.PlayerData.money.cash
    
    if customerMoney < amount then
        TriggerClientEvent('QBCore:Notify', src, 'Customer doesn\'t have enough cash', 'error')
        TriggerClientEvent('QBCore:Notify', targetId, 'You don\'t have enough cash', 'error')
        return
    end
    
    -- Remove money from customer
    Customer.Functions.RemoveMoney('cash', amount, 'restaurant-purchase')
    
    -- Add money to society account (direct MySQL update using amount column)
    MySQL.query.await('UPDATE management_funds SET amount = amount + ? WHERE job_name = ?', {
        amount,
        society
    })
    
    -- Notify both parties
    TriggerClientEvent('QBCore:Notify', src, 'Charged $' .. amount .. ' - Added to business account', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'You paid $' .. amount, 'success')
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Customer charged: $' .. amount .. ' | Society: ' .. society)
    end
end)

-- Get society account balance (Fixed - using amount column)
QBCore.Functions.CreateCallback('danglr-kitchens:server:getSocietyMoney', function(source, cb, society)
    local result = MySQL.query.await('SELECT amount FROM management_funds WHERE job_name = ?', {society})
    
    if result[1] then
        cb(result[1].amount)
    else
        cb(0)
    end
end)

-- Withdraw money from society (Fixed - using amount column)
RegisterNetEvent('danglr-kitchens:server:withdrawMoney', function(society, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Get current balance
    local result = MySQL.query.await('SELECT amount FROM management_funds WHERE job_name = ?', {society})
    
    if not result[1] then
        TriggerClientEvent('QBCore:Notify', src, 'Society account not found', 'error')
        return
    end
    
    local currentBalance = result[1].amount
    
    if currentBalance < amount then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough money in business account', 'error')
        return
    end
    
    -- Remove money from society (direct MySQL update using amount column)
    MySQL.query.await('UPDATE management_funds SET amount = amount - ? WHERE job_name = ?', {
        amount,
        society
    })
    
    -- Give money to player
    Player.Functions.AddMoney('cash', amount, 'withdrawal-from-business')
    
    TriggerClientEvent('QBCore:Notify', src, 'Withdrew $' .. amount .. ' from business account', 'success')
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 ' .. GetPlayerName(src) .. ' withdrew $' .. amount .. ' from ' .. society)
    end
end)

-- Deposit money to society (Fixed - using amount column)
RegisterNetEvent('danglr-kitchens:server:depositMoney', function(society, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player has enough cash
    local playerCash = Player.PlayerData.money.cash
    
    if playerCash < amount then
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have enough cash', 'error')
        return
    end
    
    -- Remove money from player
    Player.Functions.RemoveMoney('cash', amount, 'deposit-to-business')
    
    -- Add money to society (direct MySQL update using amount column)
    MySQL.query.await('UPDATE management_funds SET amount = amount + ? WHERE job_name = ?', {
        amount,
        society
    })
    
    TriggerClientEvent('QBCore:Notify', src, 'Deposited $' .. amount .. ' to business account', 'success')
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 ' .. GetPlayerName(src) .. ' deposited $' .. amount .. ' to ' .. society)
    end
end)

-- Hire employee
RegisterNetEvent('danglr-kitchens:server:hireEmployee', function(targetId, job, grade)
    local src = source
    local Boss = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(targetId)
    
    if not Boss or not Target then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        return
    end
    
    -- Set player's job
    Target.Functions.SetJob(job, grade)
    
    TriggerClientEvent('QBCore:Notify', src, 'Employee hired successfully!', 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'You have been hired as ' .. job .. ' (Grade ' .. grade .. ')', 'success')
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 ' .. GetPlayerName(targetId) .. ' hired as ' .. job .. ' grade ' .. grade)
    end
end)

-- Get employees
QBCore.Functions.CreateCallback('danglr-kitchens:server:getEmployees', function(source, cb, job)
    local result = MySQL.query.await('SELECT citizenid, charinfo, job FROM players WHERE job LIKE ?', {'%"name":"' .. job .. '"%'})
    
    local employees = {}
    for _, player in ipairs(result) do
        local charinfo = json.decode(player.charinfo)
        local jobData = json.decode(player.job)
        table.insert(employees, {
            citizenid = player.citizenid,
            name = charinfo.firstname .. ' ' .. charinfo.lastname,
            grade = jobData.grade.level
        })
    end
    
    cb(employees)
end)

-- Fire employee
RegisterNetEvent('danglr-kitchens:server:fireEmployee', function(citizenid, job)
    local src = source
    local Boss = QBCore.Functions.GetPlayer(src)
    
    if not Boss then return end
    
    -- Check if player is online
    local Target = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    
    if Target then
        -- Player is online, set job to unemployed
        Target.Functions.SetJob('unemployed', 0)
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, 'You have been fired from ' .. job, 'error')
    else
        -- Player is offline, update database
        MySQL.query.await('UPDATE players SET job = ? WHERE citizenid = ?', {
            json.encode({name = 'unemployed', label = 'Unemployed', payment = 10, onduty = false, isboss = false, grade = {name = 'Unemployed', level = 0}}),
            citizenid
        })
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'Employee fired successfully!', 'success')
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 Employee fired: ' .. citizenid)
    end
end)

-- Prep item
RegisterNetEvent('danglr-kitchens:server:prepItem', function(prepItem)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player has the required item
    local hasItem = Player.Functions.GetItemByName(prepItem.item)
    
    if not hasItem or hasItem.amount < prepItem.amount then
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have enough ' .. prepItem.item, 'error')
        return
    end
    
    -- Start prepping
    TriggerClientEvent('danglr-kitchens:client:startPrepping', src, prepItem)
end)

-- Finish prepping
RegisterNetEvent('danglr-kitchens:server:finishPrepping', function(prepItem)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Remove ingredient
    Player.Functions.RemoveItem(prepItem.item, prepItem.amount)
    
    -- Give reward item
    Player.Functions.AddItem(prepItem.rewardItem, prepItem.rewardAmount)
    
    TriggerClientEvent('QBCore:Notify', src, 'You prepared ' .. prepItem.rewardAmount .. 'x ' .. prepItem.rewardItem, 'success')
    
    if Config.Debug then
        print('^2[danglr-kitchens]^7 ' .. GetPlayerName(src) .. ' prepped: ' .. prepItem.item .. ' → ' .. prepItem.rewardItem)
    end
end)


if Config.Debug then
    print('^2[danglr-kitchens]^7 Server main.lua loaded')
end

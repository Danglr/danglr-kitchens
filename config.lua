Config = {}

Config.Debug = true
Config.TraySlots = 10
Config.TrayMaxWeight = 1000
Config.StorageSlots = 40
Config.StorageMaxWeight = 5000
Config.PlacementDistance = 1.3
Config.PolyzoneHeight = 5.0 -- Height of polyzone
Config.RemovePointHoldTime = 4000 -- Hold RMB for 4 seconds to exit polyzone creator
Config.AdminOnlyKitchen = true
Config.BossGrade = 3

-- Station scenarios
Config.StationScenarios = {
    ['grill'] = 'PROP_HUMAN_BBQ',
    ['fryer'] = 'PROP_HUMAN_PARKING_METER',
    ['washhands'] = 'WORLD_HUMAN_WASH_WINDOW',
    ['prep'] = 'PROP_HUMAN_SEAT_CHAIR_FOOD',
    ['drink'] = 'PROP_HUMAN_PARKING_METER'
}

-- Station labels
Config.StationLabels = {
    ['grill'] = 'Grill Station',
    ['fryer'] = 'Fryer Station',
    ['washhands'] = 'Wash Hands',
    ['prep'] = 'Prep Station',
    ['storage'] = 'Storage',
    ['drink'] = 'Drink Machine',
    ['tray'] = 'Food Tray',
    ['register'] = 'Register',
    ['management'] = 'Management'
}

Config.PrepItems = {
    {
        label = 'Cut Up Potatos',
        item = 'potato',
        amount = 1,
        rewardItem = 'cut_potato',
        rewardAmount = 5,
        duration = 3000, -- milliseconds
    },
    {
        label = 'Slice Up Tomatos',
        item = 'tomato',
        amount = 1,
        rewardItem = 'cut_tomato',
        rewardAmount = 5,
        duration = 3000,
    },
    {
        label = 'Chop Lettuce',
        item = 'lettuce',
        amount = 1,
        rewardItem = 'cut_lettuce',
        rewardAmount = 6,
        duration = 3000,
    },
    {
        label = 'Slice Up Cheese Block',
        item = 'cheeseblock',
        amount = 1,
        rewardItem = 'cut_cheese',
        rewardAmount = 20,
        duration = 6000,
    },
    -- Add more prep items here following the same format
}

return Config

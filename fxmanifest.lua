fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'danglr'
description 'Kitchen System with Dynamic Placement'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/polyzone.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'qb-core',
    'ox_lib',
    'oxmysql',
    'qb-target'
}

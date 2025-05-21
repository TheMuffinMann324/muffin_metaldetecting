fx_version 'cerulean'
game 'gta5'

description 'Muffin Metal Detecting - QBCore Metal Detector Script'
version '1.0.0'
author 'Muffin'

shared_scripts {
    '@qb-core/shared/locale.lua',
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'config.lua'
}

client_scripts {
    'client.lua',
}

server_scripts {
    'version.lua',
    'server.lua',
    '@oxmysql/lib/MySQL.lua'  -- Added for database functionality
}

dependencies {
    'qb-core',
    'PolyZone'
    -- Uncomment the one you're using:
    -- 'qb-target',
    -- 'ox_target'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles.css',
    'html/app.js'
}

lua54 'yes'

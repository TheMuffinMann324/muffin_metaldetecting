# muffin_metaldetecting
A comprehensive QBCore/Qbox metal detecting script that allows players to search for buried treasures along beaches and other designated areas. This realistic metal detector simulation features beeping sounds that intensify as players get closer to treasures, interactive digging, and a treasure map system.


# Install
Requirements
* QBCore Framework or Qbox. sorry to the last of you still using esx
* PolyZone
* qb-target or ox_target
* RP Emotes or any emote script with 'digiscan' and 'garden' emotes
* This should work with both qb-inventory and ox_inventory if you use qbox bridge


# SetupSteps
* Download the muffin_metaldetecting folder from the GitHub repository
* Place the folder in your server's resources directory
* Add ensure muffin_metaldetecting to your server.cfg
* Configure the script by editing config.lua to match your server's economy and preferences
* Add the required items to your QBCore shared items
* Add the following to your qb-core/shared/items.lua:
* YOU WILL NEED YOUR OWN IMAGES!

```
['metaldetector'] = {
    ['name'] = 'metaldetector',
    ['label'] = 'Metal Detector',
    ['weight'] = 2000,
    ['type'] = 'item',
    ['image'] = 'metaldetector.png',
    ['unique'] = true,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'A device used to find buried treasures'
},
['rake'] = {
    ['name'] = 'rake',
    ['label'] = 'Beach Rake',
    ['weight'] = 1500,
    ['type'] = 'item',
    ['image'] = 'rake.png',
    ['unique'] = true,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'Used to rake through sand and find treasures'
},
['messagebottle'] = {
    ['name'] = 'messagebottle',
    ['label'] = 'Message in a Bottle',
    ['weight'] = 500,
    ['type'] = 'item',
    ['image'] = 'messagebottle.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'An old bottle with a treasure map inside'
}, 
```
# Usage
* Players need to have the metal detector item in their inventory.
* They need to be in one of the designated treasure hunting zones.
* As they move around, the beeping sound gets faster when they get closer to a treasure.
* When close enough to the treasure, an interaction option to dig appears.
* After digging, players receive a random reward based on the configuration.
* Players can use the /detectingboard command to show the leaderboard. Sql should be done automatically on first start


# Support
I do not have a discord yet but if you really need support you can message my discord Muffin#6123


You are free to edit this script however you like just dont slap your name on it and call it yours.




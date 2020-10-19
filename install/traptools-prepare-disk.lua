local osversion = loadfile('/OSVERSION')()
local fse = require('fs-extra')

local label = osversion;
local setlabel = String(true)
local reboot = String(true)
local setboot = String(true)

local data = '{ label="'.. label ..'", setlabel='.. setlabel ..', reboot='.. reboot ..', setboot='.. setboot ..' }'

fse.writeFile('/.prop', data)

require('shell').execute('label / "'.. label ..'"')




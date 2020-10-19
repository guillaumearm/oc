local osversion = require('/OSVERSION')

local label = osversion;
local setlabel = String(true);
local reboot = String(true);
local setboot = String(true);

print('{ label="'.. label ..'", setlabel='.. setlabel ..', reboot='.. reboot ..', setboot='.. setboot ..' }')




local db = require('persistable')('working_directory')
local shell = require('shell')

local arg = ...
local wdName = arg or 'default'

local wdTable = db.read() or {}
local cwd = shell.getWorkingDirectory()

wdTable[wdName] = cwd
db.write(wdTable)

print('> new "' .. wdName .. '" working dir: ' .. cwd)
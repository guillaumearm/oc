local db = require('persistable')('working_directory')
local shell = require('shell')

local arg = ...
local wdName = arg or ''

local wdTable = db.read() or {}
dump(wdTable)
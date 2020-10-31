local db = require('persistable')('working_directory')

local wdTable = db.read() or {}

dump(wdTable)
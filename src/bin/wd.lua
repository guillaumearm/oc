local db = require('persistable')('working_directory')
local shell = require('shell')

local arg = ...
local wdName = arg or 'default'

local wdTable = db.read() or {}

local path = wdTable[wdName]

if path then
  local oldPwd = shell.getWorkingDirectory()
  shell.setWorkingDirectory(path)

  wdTable['-'] = oldPwd
  db.write(wdTable)
else
  print('Error: "' .. wdName .. '" is unknown!')
end
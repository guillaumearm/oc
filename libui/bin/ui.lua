local os = require('os')
local shell = require('shell')
local execUI = require('ui/exec')

local args = pack(...)

local givenFileName = head(args)
local restArgs = tail(args)

local filePath = shell.resolve(givenFileName, 'lua')

local getcontainer = loadfile(filePath)
local container, readErr = getcontainer()

local function printQuit(...)
  printErr(...)
  os.exit(1)
end

if readErr then
  printQuit(readErr)
end

local ok, err = execUI(container, unpack(restArgs))

if not ok then printQuit(err) end


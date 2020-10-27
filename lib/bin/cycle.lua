local os = require('os')
local shell = require('shell')
local rxe = require('rx-extra')

local args = pack(...)

local firstArg = head(args)
local restArgs = tail(args)

local verbose = false

local function printVerbose(message)
  if (verbose) then
    print('> cycle: ' .. message)
  end
end

if firstArg == '-v' or firstArg == '--verbose' then
  verbose = true

  firstArg = head(restArgs)
  restArgs = tail(restArgs)
end

local givenFileName = firstArg

local filePath = shell.resolve(givenFileName, 'lua')

local getcycle = loadfile(filePath)
local cycle, readErr = getcycle(unpack(restArgs))

local function printQuit(...)
  printErr(...)
  os.exit(1)
end

if readErr then
  printQuit(readErr)
end

printVerbose('start program')

local ok, err = rxe.runCycle(cycle)

printVerbose('stop program')

if not ok then printQuit(err) end


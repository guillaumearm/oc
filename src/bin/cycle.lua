local shell = require('shell')
local runCycle = require('cycle')

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

local getcycle, syntaxError = loadfile(filePath)

if not getcycle then
  printExit(syntaxError)
end

local cycle, readErr = getcycle(unpack(restArgs))

if readErr then
  printExit(readErr)
end

printVerbose('start program')

local sub = runCycle(cycle)
sub:unsubscribe()

printVerbose('stop program')



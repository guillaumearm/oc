local os = require('os')
local shell = require('shell')
local rx = require('rx')
local rxe = require('rx-extra')

local args = pack(...)

local firstArg = head(args)
local restArgs = tail(args)

local verbose = false
local observer = nil

local function printVerbose(message)
  if (verbose) then
    print('> rx: ' .. message)
  end
end

if firstArg == '-v' or firstArg == '--verbose' then
  verbose = true
  observer = rx.Observer.create(print, printError, noop)

  firstArg = head(restArgs)
  restArgs = tail(restArgs)
end

local givenFileName = firstArg

local filePath = shell.resolve(givenFileName, 'lua')

local getobservable = loadfile(filePath)
local observable, readErr = getobservable(unpack(restArgs))

local function printQuit(...)
  printErr(...)
  os.exit(1)
end

if readErr then
  printQuit(readErr)
end

printVerbose('start observable program')

local ok, err = rxe.run(observable, observer)

printVerbose('stop observable program')

if not ok then printQuit(err) end


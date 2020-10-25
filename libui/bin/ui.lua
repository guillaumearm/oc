local os = require('os')
local shell = require('shell')
local runUI = require('ui/run')

local args = pack(...)

local givenFileName = head(args)
local restArgs = tail(args)

local filePath = shell.resolve(givenFileName, 'lua')
local getcomponent = loadfile(filePath)

local function printQuit(...)
  printErr(...)
  os.exit(1)
end

if readErr then
  printQuit(readErr)
end

local function assertValidComponentDefinition(cd)
  if not cd then
    printQuit('UI Error: no component definition found')
  end

  if not cd.view then
    printQuit('UI ERROR: no view provided in the component definition')
  end

  if isNotFunction(cd.view) then
    printQuit('UI ERROR: not a valid view')
  end

  if cd.updater and isNotFunction(cd.updater) then
    printQuit('UI ERROR: not a valid updater')
  end

  if cd.handler and isNotFunction(cd.handler) then
    printQuit('UI ERROR: not a valid handler')
  end

  if cd.capture and isNotTable(cd.capture) then
    printQuit('UI ERROR: invalid capture events (not a table)')
  end

  if cd.capture then
    forEach(function(e)
      if isNotString(e) then
        printQuit('UI ERROR: invalid capture events (not a string)')
        return stop
      end
    end, cd.capture)
  end

  return cd
end

local function getComponentDefinition(c)
  if not c then
    printQuit('UI ERROR: nothing exported')
  end

  if isFunction(c) then
    return assertValidComponentDefinition(c(unpack(restArgs)))
  end

  return assertValidComponentDefinition(c)
end

local component, err = getcomponent()

if err then
  printQuit(err)
end

local cd = getComponentDefinition(component)

local ok, err = pcall(runUI, cd.view, cd.updater, cd.handler, cd.capture)

if not ok then printQuit(err) end


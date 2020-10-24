local shell = require('shell')
local exec = require('shell').execute

local firstArg = ...

-------------------------------------------------------------------------------

local PACKAGE_LIST = {
  "traptools",
  "openos-patches",
  "libui",
  "libui-demo",
  "redstone-onoff",
  "media",
  "wd"
}

local DAEMONS_TO_ACTIVATE = {
  "media",
  "redstone-onoff"
}

-------------------------------------------------------------------------------


local uninstall = function()
  -- Uninstall all packages
  for k, v in pairs(PACKAGE_LIST) do
    exec('oppm uninstall ' .. v)
  end
end

local install = function()
  -- init global utils
  exec('/boot/11_global_utils');

  -- Activate all listed daemons
  for k, v in pairs(DAEMONS_TO_ACTIVATE) do
    exec('rc ' .. v .. ' enable')
  end


  -- Set path for demos
  shell.setPath(shell.getPath() .. ":/bin/demo:/usr/bin/demo")

  -- Reboot computer
  exec('reboot')
end

function printUsage()
  print('Usage: traptools <init|uninstall>')
end

-------------------------------------------------------------------------------
local isLegacyInstallCommand = firstArg == 'i' or firstArg == 'install'
if isLegacyInstallCommand then
  firstArg = 'init'
  printErr('Warning: the "' .. firstArg .. '" command is deprecated')
  printErr('Prefer use "traptools init"')
  exec('sleep 2')
end
-------------------------------------------------------------------------------

if firstArg == 'init' or firstArg == 'i' or firstArg == 'install' then
  install()
elseif firstArg == 'uninstall' then
  uninstall()
else
  printUsage()
end

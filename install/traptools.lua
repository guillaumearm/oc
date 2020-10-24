local exec = require('shell').execute

local firstArg = ...

local uninstall = function()
  -- Packages list
  local packageList = {
    "traptools",
    "openos-patches",
    "libui",
    "libui-demo",
    "redstone-onoff",
    "media",
    "wd"
  }

  -- Uninstall all packages
  for k, v in pairs(packageList) do
    exec('oppm uninstall ' .. v)
  end
end

local install = function()
  -- init global utils
  exec('/boot/11_global_utils');

  -- Daemons list
  local daemonsToActivate = {
    "media",
    "redstone-onoff"
  }

  -- Activate all listed daemons
  for k, v in pairs(daemonsToActivate) do
    exec('rc ' .. v .. ' enable')
  end

  -- Reboot computer
  exec('reboot')
end

if firstArg == 'i' or firstArg == 'install' then
  install()
elseif firstArg == 'uninstall' then
  uninstall()
else
  print('Usage: traptools <install|uninstall>')
end

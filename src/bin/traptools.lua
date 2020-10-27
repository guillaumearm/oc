local exec = require('shell').execute

local firstArg, secondArg = ...

-------------------------------------------------------------------------------

local PACKAGE_LIST = {
  "traptools",
  "global-utils",
  "liblog",
  "persistable",
  'fs-extra',
  'rx',
  'rx-extra',
  'rx-cycle',
  "openos-patches",
  "libui",
  "libui-demo",
  "redstone-onoff",
  "media",
  "wd",
  "shedit"
}

local DAEMONS_TO_ACTIVATE = {
  "media",
  "redstone-onoff"
}

-------------------------------------------------------------------------------


local uninstallCommand = function(isHard)
  -- backup
  if not isHard then
    exec('mv /lib/core/original_boot.lua /tmp/original_boot.lua')
    exec('mv /lib/original_vt100.lua /tmp/vt100.lua')
    exec('mv /etc/profile.lua /tmp/saved_profile.lua')
  end

  -- Uninstall all packages
  for k, v in pairs(PACKAGE_LIST) do
    exec('oppm uninstall ' .. v)
  end

  -- restore
  if not isHard then
    exec('mv /tmp/original_boot.lua /lib/core/boot.lua')
    exec('mv /tmp/vt100.lua /lib/vt100.lua')
    exec('mv /tmp/saved_profile.lua /etc/profile.lua')
  end
end

local initCommand = function()
  -- init global utils
  exec('/boot/11_global_utils');

  -- Enable all listed daemons
  for k, v in pairs(DAEMONS_TO_ACTIVATE) do
    exec('rc ' .. v .. ' enable')
  end

  -- Reboot computer
  exec('reboot')
end

function printUsage()
  print('Usage:')
  print('\t\t traptools init')
  print('\t\t traptools uninstall [--safe]')
  print('\t\t traptools help [<command>]')
  print('')
  print('type `man traptools` for more details')
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
  initCommand()
elseif firstArg == 'uninstall' then
  local isHard = secondArg == '--hard' or secondArg == '-h'

  if secondArg and not isHard then
    printErr('Error: unknown flag "' .. secondArg .. '" for uninstall command')
  else
    uninstallCommand(isHard)
  end
  
elseif firstArg == 'help' and secondArg == 'init' then
  print('`init` - this is the postinstall script, it enables embeded daemons and reboot the computer')
elseif firstArg == 'help' and secondArg == 'uninstall' then
  print('`uninstall`        - remove traptools from your system and backup necessary files needed by OpenOS')
  print('`uninstall --hard|-h` - hardly remove traptools, it may breaks your system!')
else
  printUsage()
end
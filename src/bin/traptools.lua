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
  'cycle',
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
  for _, v in pairs(PACKAGE_LIST) do
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
  for _, v in pairs(DAEMONS_TO_ACTIVATE) do
    exec('rc ' .. v .. ' enable')
  end

  -- Reboot computer
  exec('reboot')
end

-- TODO: documentation (in man)
local reinstallCommand = function()
  local commands = {
    'oppm > /dev/null',
    'ls /media/traptools > /dev/null',
    'traptools uninstall --hard',
    'sleep 2', -- workaround
    'tree /media/traptools', -- workaround
    'sleep 4', -- workaround
    'oppm install traptools /media/traptools',
    '/bin/cp -vrx --skip=.prop /media/traptools/. /',
    'traptools init',
    'echo done'
  }

  exec(join(' && ', commands))
end

local SYNC_PREFIX_URL = 'https://raw.githubusercontent.com/guillaumearm/oc/master/src/'

local syncCommand = function()
  local filesToDownload = {
    'lib/rx.lua'
  }

    -- init global utils
    exec('/boot/11_global_utils');

  forEach(function(file)
    print('> Downloading ' .. file)
    exec('wget -f ' .. SYNC_PREFIX_URL .. file .. ' /' .. file)
  end, filesToDownload)
end

local function printUsage()
  print('Usage:')
  print('\t\t traptools init')
  print('\t\t traptools uninstall [--hard]')
  print('\t\t traptools reinstall')
  print('\t\t traptools update')
  print('\t\t traptools sync')
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
  exec('sleep 4')
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
elseif firstArg == 'reinstall' or firstArg == 'update' then
  reinstallCommand()
elseif firstArg == 'sync' then
  syncCommand()
elseif firstArg == 'help' and secondArg == 'init' then
  print('`init` - this is the postinstall script, it enables embeded daemons and reboot the computer')
elseif firstArg == 'help' and secondArg == 'uninstall' then
  print('`uninstall`        - remove traptools from your system and backup necessary files needed by OpenOS')
  print('`uninstall --hard|-h` - hardly remove traptools, it may breaks your system!')
elseif firstArg == 'help' and secondArg == 'reinstall' then
  print('`reinstall` - Used to hard reinstall traptools on /media/traptools')
elseif firstArg == 'help' and secondArg == 'update' then
  print('`update` - alias for `traptools reinstall`')
elseif firstArg == 'help' and secondArg == 'sync' then
  print('`sync` - directly fetch some files (used for development only)')
else
  printUsage()
end

local exec = require('shell').execute

local firstArg, secondArg = ...

local path = firstArg or '/'

-- Reinstall traptools
exec('traptools-uninstall')
exec('oppm install -f traptools ' .. path)

if secondArg == '--reboot' then
  exec('traptools-install')
end


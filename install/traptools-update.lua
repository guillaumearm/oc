local exec = require('shell').execute

local firstArg, secondArg = ...

local path = firstArg or '/'

-- Reinstall traptools
exec('traptools-uninstall')
exec('sleep 4')
exec('oppm install traptools ' .. path)

if secondArg == '--install' then
  if path ~= '/' then
    exec('install --fromDir ' .. path .. ' --toDir /')
  end
  exec('traptools-install')
end


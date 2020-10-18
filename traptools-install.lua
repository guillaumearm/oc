local exec = require('shell').exec

-- Daemons list
local daemonsToActivate = {
  "media",
  "redstone-onoff"
}

-- Activate all listed daemons
for k, v in pairs(daemonsToActivate) do
  exec('rc ' .. v .. ' enable')
  exec('rc ' .. v .. ' start')
end

-- Cleanup
exec('rm -f /usr/bin/traptools-install.lua')

-- Reboot computer
exec('reboot')

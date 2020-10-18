local exec = require('shell').execute

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

local exec = require('shell').execute

-- Reinstall traptools
exec('traptools-uninstall')
exec('oppm install -f traptools')
exec('traptools-install')

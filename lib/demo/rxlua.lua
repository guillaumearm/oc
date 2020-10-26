local os = require('os')
local Rx = require('rx')

Rx.Observable.fromRange(1, 8)
  :filter(function(x) return x % 2 == 0 end)
  :concat(Rx.Observable.of('who do we appreciate'))
  :map(function(value) return value .. '!' end)
  :delay(1000)
  :subscribe(print)

os.sleep(3)

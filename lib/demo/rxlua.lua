local event = require('event')
local Rx = require('rx')

local sub = Rx.Observable.fromRange(1, 8)
  :filter(function(x) return x % 2 == 0 end)
  :concat(Rx.Observable.of('who do we appreciate'))
  :map(function(value) return value .. '!' end)
  :delay(1000)
  :subscribe(print, printErr, function() event.push('interrupted') end)


event.pull('interrupted')
sub:unsubscribe()

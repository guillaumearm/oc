local Rx = require('rx')

return Rx.Observable.fromRange(1, 8)
  :filter(function(x) return x % 2 == 0 end)
  :concat(Rx.Observable.of('who do we appreciate'))
  :map(function(value) return value .. '!' end)
  :delay(1000)

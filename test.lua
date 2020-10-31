require('./src/boot/11_global_utils')

local res = Do(function()
  local a = yield(just(1))
  local b = yield(just(2))
  local c = yield(just(3))

  return a + b + c
end):fallbackTo('no value')

print(res:extract())

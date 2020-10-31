---------------------------------------------------------------------------
------------  Name: global-utils v0.17
------------  Description: Global functional utilities
------------  Author: Trapcodien
---------------------------------------------------------------------------

local function concatTable(t1, t2)
  local t1length = #t1
  local i = 1
  local t = {}

  while i <= t1length do
    t[i] = t1[i]
    i = i + 1
  end

  local t2length = #t2
  local i2 = 1

  while i2 <= t2length do
    t[i] = t2[i2]
    i = i + 1
    i2 = i2 + 1
  end

  t.n = i - 1

  return t
end

_G.curry = function(func, num_args)
  num_args = num_args or debug.getinfo(func, "u").nparams
  if num_args < 2 then return func end
  local function helper(argtrace, n)
    if n < 1 then
      return func(table.unpack(argtrace))
    else
      return function (...)
        return helper(concatTable(argtrace, pack(...)), n - select("#", ...))
      end
    end
  end
  return helper({}, num_args)
end

_G.curryN = function(num_args, func) return curry(func, num_args) end

_G.import = function(path)
  package.loaded[path] = nil
  return require(path)
end

local function simpleCompose(f, g)
  return function(...)
    return f(g(...))
  end
end

_G.fst = function(a, _) return a end
_G.snd = function(_, b) return b end
_G.third = function(_, _, c) return c end
_G.fourth = function(_, _, _, d) return d end
_G.fifth = function(_, _, _, _, e) return e end

_G.pipe = function(f, g, ...)
  if g == nil then return f end

  local nextFn = simpleCompose(g, f)
  return pipe(nextFn, ...)
end

_G.compose = function(...)
  local reversedArgs = reverse(pack(...))
  return pipe(unpack(reversedArgs))
end

_G.flip = function(f)
  return curryN(2, function(a, b)
    return f(b, a)
  end)
end

_G.applyTo = function(...)
  local args = pack(...)
  return function(...)
     return pipe(...)(unpack(args))
  end
end

_G.apply = function(fn, ...)
  local args = pack(...)
  return function()
    fn(unpack(args))
  end
end

_G.cb = apply

_G.pack = table.pack
_G.unpack = table.unpack

_G.upper = string.upper
_G.lower = string.lower
_G.toUpper = string.upper
_G.toLower = string.lower

_G.leftPadString = curryN(2, function(n, str)
  local pad = n - length(str);
  if pad < 1 then return str end

  return string.rep(' ', pad) .. str
end)

_G.rightPadString = curryN(2, function(n, str)
  local pad = n - length(str);
  if pad < 1 then return str end

  return str .. string.rep(' ', pad)
end)

_G.leftPad = _G.leftPadString
_G.rightPad = _G.rightPadString

_G.centerStringWith = curryN(3, function (givenChar, width, str)
  local firstChar = prop(1, givenChar)
  local totalPad = width - length(str);
  if totalPad < 1 then return str end

  local leftPad = math.floor(totalPad / 2)
  local rightPad = ternary(isOdd(totalPad), leftPad + 1, leftPad)

  return string.rep(firstChar, leftPad) .. str .. string.rep(firstChar, rightPad);
end)

_G.centerString = curryN(2, function(width, str)
  return centerStringWith(' ', width, str)
end)

_G.null = setmetatable({}, { __tostring=function() return "null" end })

-- used to stop forEach execution
_G.stop = setmetatable({}, { __tostring=function() return "stop" end })

_G.length = function(t)
  if isString(t) then return #t end

  local largerIndex = 0

  for k,_ in pairs(t) do
    if type(k) == 'number' and k > largerIndex then
      largerIndex = k
    end
  end

  return largerIndex
end

_G.countItems = function(t)
  if isString(t) then return #t end

  local i = 0

  forEach(function()
    i = i + 1
  end, t)

  return i
end

_G.flatten = function(t)
  local ret = {}
  for _, v in ipairs(t) do
    if isArray(v) then
      for _, fv in ipairs(flatten(v)) do
        ret[#ret + 1] = fv
      end
    else
      ret[#ret + 1] = v
    end
  end

  ret.n = #ret
  return ret
end

_G.concat = curryN(2, function(t1, t2)
  if isString(t1) then return t1 .. t2 end
  return concatTable(t1, t2)
end)

local stringCount = function(substr, str)
  local i = 0
  local foundPos = 0

  while isNotNil(foundPos) do
    foundPos = string.find(str, substr, foundPos + 1, true)
    if isNotNil(foundPos) then
      i = i +1
    end
  end

  return i
end

_G.countWhen = curryN(2, function(predicate, t)
  local i = 0

  forEach(function(v, k)
    if predicate(v, k) then
      i = i + 1
    end
  end, t)

  return i
end)

_G.count = curryN(2, function(v, t)
  if isString(v) and isString(t) then return stringCount(v, t) end
  return countWhen(identical(v), t)
end)

local simpleMerge = function(t1, t2)
  local ret = clone(t1)

  forEach(function(v, k)
    ret[k] = v
  end, t2)

  return ret
end

_G.assign = function(t1, t2, ...)
  if isNil(t2) then return t1 end
  local merged = simpleMerge(t1, t2)
  return assign(merged, ...)
end

_G.mergeTo = curryN(2, simpleMerge)
_G.merge = mergeTo

_G.withDefault = flip(merge)

_G.complement = function(predicate)
  return function(...)
    return not predicate(...)
  end
end

_G.ternary = curryN(3, function(bool, v1, v2)
  if bool then
    return v1
  else
    return v2
  end
end)

_G.Nil = function() return nil end
_G.toNil = Nil

_G.Table = function(...)
  local firstArg = ...
  if isFunction(firstArg) then
    local ret = {}
    for v in firstArg do
      table.insert(ret, v)
    end
    return ret
  end
  return pack(...)
end

_G.toTable = Table

_G.String = tostring
_G.toString = String

_G.Number = function(x)
  if isBoolean(x) then
    return ternary(x, 1, 0)
  elseif isNil(x) then
    return 0
  end

  return tonumber(x)
end

_G.toNumber = Number

_G.isStringIsNumber = function(v)
  if not isString(v) then return false end
  return isNumber(Number(v))
end

_G.max = curryN(2, function(a, b)
  return math.max(a, b)
end)

_G.min = curryN(2, function(a, b)
  return math.min(a, b)
end)

_G.abs = math.abs

_G.negate = function(x) return -x end

_G.arrayOf = function(v) return {v} end

_G.getValueOr = curryN(2, function(placeholder, m)
  if isEmpty(m) then return placeholder end
  return head(m)
end)

_G.ensureTable = function(x)
  if isTable(x) then return x end
  return arrayOf(x)
end

_G.ensureFunction = function(x)
  return when(isNotFunction, always)(x)
end

_G.isWhitespace = function(v)
  return v == ' ' or v == '\t' or v == '\n'
end

_G.isNotWhitespace = complement(isWhitespace)

-- ACCESSORS/UPDATERS

_G.replaceCharAt = curryN(3, function(pos, c, str)
  if pos < 0 then
    pos = #str + 1 + abs(pos)
  end
  return string.sub(str, 1, pos - 1) .. c .. string.sub(str, pos + 1)
end)

_G.removeCharAt = curryN(2, function(pos, str)
  return replaceCharAt(pos, '', str)
end)

_G.insertCharAt = curryN(3, function(pos, c, str)
  if pos < 0 then
    pos = #str + 2 + abs(pos)
  elseif pos == 0 then
    pos = 1
  end

  return string.sub(str, 0, pos - 1) .. c .. string.sub(str, pos)
end)

_G.prop = curryN(2, function(k, t)
  if isString(t) then return string.sub(t, k, k) end
  if isNotTable(t) then return nil end
  return t[k]
end)

_G.propOr = curryN(3, function(fallbackValue, k, t)
  return prop(k, t) or fallbackValue
end)

_G.nth = function(n)
  return function(...)
    return pack(...)[n]
  end
end

_G.setProp = curryN(3, function(k, v, t)
  if isString(t) then
    return replaceCharAt(k, v, t)
  end

  if isNotTable(t) then return t end
  local newTable = clone(t)
  newTable[k] = v

  return newTable
end)

_G.setNonNilProp = curryN(3, function(k, v, t)
  if isString(t) and isNotNil(prop(k, t)) then
    return replaceCharAt(k, v, t)
  end

  if isNotTable(t) then return t end
  if isNil(t[k]) then return t end
  return setProp(k, v, t)
end)

_G.removeProp = curryN(2, function(k, t)
  return omit(k)(t)
end)

_G.updateProp = curryN(3, function(k, f, t)
  return setProp(k, f(prop(k, t)), t)
end)

_G.updateNonNilProp = curryN(3, function(k, f, t)
  local v = prop(k, t)
  if isNil(v) then return t end
  return setProp(k, f(v), t)
end)

_G.path = function(...)
  local ks = pack(...)
  local firstKey = head(ks)

  return function(t)
    if isNil(t) or isNil(firstKey) then return t end
    return path(unpack(tail(ks))) (prop(firstKey, t))
  end
end

_G.pathOr = function(fallbackValue, ...)
  local args = pack(...)
  return function(t)
    return path(unpack(args))(t) or fallbackValue
  end
end

_G.evolve = curryN(2, function(evolveTable, t)
  t = t or {}
  local updatedTable = mapIndexed(function(fn, id)
    local elem = t[id]
    if isTable(fn) then return evolve(fn, elem) end
    return fn(elem)
  end, evolveTable)

  return merge(t, updatedTable)
end)

-------------- TODO
_G.setPath = nil
_G.setNonNilPath = nil
_G.removePath = nil
_G.updatePath = nil
_G.updateNonNilPath = nil

_G.propCompare = nil
_G.pathCompare = nil

_G.propEq = curryN(3, function(k, v, t)
  return equals(v, prop(k, t))
end)

_G.pathEq = nil
_G.propIdentical = nil
_G.pathIdentical = nil

-------------------

_G.keys = function(t)
  local ret = {}

  local i = 1

  forEach(function(_, key)
    ret[i] = key
    i = i + 1
  end, t)

  ret.n = i - 1
  return ret
end

_G.values = function(t)
  local ret = {}
  local i = 1

  forEach(function(value, _)
    ret[i] = value
    i = i + 1
  end, t)

  ret.n = i - 1
  return ret
end

_G.omit = function(...)
  local keys = pack(...)
  return function(t)
    return reject(function(_, key)
      local foundIndex = findKey(identical(key), keys)
      return isNotNil(foundIndex)
    end, t)
  end
end

_G.pick = function(...)
  local keys = pack(...)
  return function(t)
    return filter(function(_, key)
      local foundIndex = findKey(identical(key), keys)
      return isNotNil(foundIndex)
    end, t)
  end
end

_G.append = curryN(2, function(v, t)
  if isString(t) then return t .. v end
  return concat(t, {v})
end)

_G.prepend = curryN(2, function(v, t)
  if isString(t) then return v .. t end
  return concat({v}, t)
end)

_G.take = curryN(2, function(n, t)
  if isString(t) then return string.sub(t, 0, n) end

  local ret = {}
  local taken = 0

  forEach(function(v, k)
    if taken >= n then return stop end
    if isNumber(k) then
      ret[k] = v
      taken = taken + 1
    end
  end, t)

  return ret
end)

_G.drop = curryN(2, function(n, t)
  if n <= 0 then return t end
  if isString(t) then
    return string.sub(t, n + 1)
  end

  local ret = {}
  local dropped = 0
  local i = 1

  forEach(function(v, _)
    if dropped >= n then
      ret[i] = v
      i = i + 1
    else
      dropped = dropped + 1
    end
  end, t)

  return ret
end)

_G.takeLast = curryN(2, function(n, t)
  if isString(t) then
    return string.sub(t, -n)
  end

  local size = length(compact(t))
  local toDrop = math.max(0, size - n)
  return drop(toDrop, t)
end)

_G.dropLast = curryN(2, function(n, t)
  local size = length(compact(t))
  local toTake = math.max(0, size - n)
  return take(toTake, t)
end)

local stringDropUntil = function(predicate, str)
  local ret = ''
  local shouldDrop = true

  forEach(function(c, k)
    if shouldDrop then
      shouldDrop = not predicate(c, k)
    end

    if not shouldDrop then
      ret = ret .. c
    end
  end, str)

  return ret
end

_G.dropUntil = curryN(2, function(predicate, t)
  if isString(t) then return stringDropUntil(predicate, t) end

  local ret = {}
  local shouldDrop = true
  local i = 1

  forEachIndexed(function(v, k)
    if shouldDrop then
      shouldDrop = not predicate(v, k)
    end

    if not shouldDrop then
      ret[i] = v
      i = i + 1
    end
  end, t)

  return ret
end)

local stringTakeUntil = function(predicate, str)
  local ret = ''
  local shouldTake = true

  forEach(function(c, k)
    shouldTake = not predicate(c, k)
    if not shouldTake then return stop end
    ret = ret .. c
  end, str)

  return ret
end

_G.takeUntil = curryN(2, function(predicate, t)
  if isString(t) then return stringTakeUntil(predicate, t) end

  local ret = {}
  local i = 1
  local shouldTake = true

  forEachIndexed(function(v, k)
    shouldTake = not predicate(v, k)
    if not shouldTake then return stop end
    ret[i] = v
    i = i + 1
  end, t)

  return ret
end)

_G.dropLastUntil = curryN(2, function(predicate, t)
  return applyTo(t)(
    reverse,
    dropUntil(predicate),
    reverse
  )
end)

_G.takeLastUntil = curryN(2, function(predicate, t)
  return applyTo(t)(
    reverse,
    takeUntil(predicate),
    reverse
  )
end)

_G.head = function(t)
  if isString(t) then return prop(1, t) end

  local foundHead = nil

  forEach(function(v)
    foundHead = v
    return stop
  end, t)

  return foundHead
end

_G.first = head

_G.tail = drop(1)

_G.last = function(t)
  if isString(t) then return string.sub(t, -1) end
  return t[length(t)]
end

_G.lastIndex = length

_G.lastKey = lastIndex

-------- STRING UTILS ----------
_G.trimStart = dropUntil(isNotWhitespace)
_G.trimEnd = dropLastUntil(isNotWhitespace)
_G.trim = pipe(trimStart, trimEnd)

_G.join = curryN(2, function(sep, t)
  return table.concat(t, sep)
end)

local simpleSplit = function(sep, str)
  if str == "" then return nil end

  local sepPos, nextPos = string.find(str, sep, 1, true)
  if isNil(nextPos) then return str end

  local firstWord = string.sub(str, 1, sepPos - 1)
  local secondWord = string.sub(str, nextPos + 1)

  return firstWord, secondWord
end

_G.split = curryN(2, function(sep, str)
  local ret = {}
  local restString = str

  while isNotEmpty(restString) do
    local firstWord, secondWord = simpleSplit(sep, restString)
    if isNotNil(firstWord) then
      table.insert(ret, firstWord)
    end
    restString = secondWord
  end

  return ret
end)

_G.startsWith = curryN(2, function(substr, str)
  return take(#substr, str) == substr
end)

_G.endWith = curryN(2, function(substr, str)
  return takeLast(#substr, str) == substr
end)

_G.contains = curryN(2, function(value, t)
  if isString(value) and isString(t) then
    return Boolean(string.find(t, value, 1, true))
  end

  local valueFound = false

  forEach(function(v)
    if value == v then
      valueFound = true
      return stop
    end
  end, t)

  return valueFound
end)

_G.oneOf = flip(contains)

-- TYPE PREDICATES

_G.is = function(givenType)
  return function(value)
    return type(value) == givenType
  end
end

_G.isNot = function(givenType)
  return function(value)
    return type(value) ~= givenType
  end
end

_G.isString = is('string')
_G.isTable = is('table')

_G.isArray = function(x)
  return isTable(x) and (Boolean(x[1]) or isEmpty(x))
end

_G.isNumber = is('number')
_G.isBoolean = is('boolean')
_G.isFunction = is('function')

_G.isNotString = isNot('string')
_G.isNotTable = isNot('table')
_G.isNotNumber = isNot('number')
_G.isNotBoolean = isNot('boolean')
_G.isNotFunction = isNot('function')

_G.isNull = function(v) return v == null end
_G.isNotNull = complement(isNull)

_G.isNil = function(v) return v == nil or v == null end
_G.isNotNil = complement(isNil)

_G.Boolean = function(v)
  local isFalsy = isNil(v) or v == '' or v == 0 or v == false
  return not isFalsy
end

_G.isTruthy = Boolean
_G.isFalsy = complement(Boolean)

_G.isEmpty = function(v)
  if v == '' then return true end
  if isNil(v) then return true end

  if isTable(v) then
    local iterated = false

    forEach(function(_)
      iterated = true
      return stop
    end, v)

    return not iterated
  end

  return false
end

_G.isNotEmpty = complement(isEmpty)

_G.isHuge = function(x) return x == math.huge end
_G.isNotHuge = complement(isHuge)

_G.byte = function(c)
  return string.byte(c)
end

_G.char = function(code)
  return string.char(code)
end

_G.isStringIsNumeric = function(v)
  if not isString(v) then return false end
  return isStringIsNumber(head(v))
end

_G.lt = curryN(2, function(a, b)
  return b < a
end)

_G.lte = curryN(2, function(a, b)
  return b <= a
end)

_G.gt = curryN(2, function(a, b)
  return b > a
end)

_G.gte = curryN(2, function(a, b)
  return b >= a
end)

_G.isZero = function(x) return x == 0 end
_G.isNotZero = complement(isZero)

-- BASIC LOGIC

_G.identical = curryN(2, function(a, b) return a == b end)
_G.notIdentical = curryN(2, function(a, b) return not(a == b) end)

_G.isTrue = identical(true)
_G.isNotTrue = complement(isTrue)

_G.isFalse = identical(false)
_G.isNotFalse = complement(isFalse)

_G.xor = curryN(2, function(a, b)
  return (a == true and b == false) or (a == false and b == true)
end)

_G.ifElse = curryN(3, function(predicate, transformerThen, transformerElse)
  return function(...)
    if predicate(...) then
      return transformerThen(...)
    else
     return transformerElse(...)
    end
  end
end)

_G.when = curryN(2, function(predicate, transformerThen)
  return function(...)
    return ifElse(predicate, transformerThen, identity)(...)
  end
end)

_G.defaultTo = curryN(2, function(fallbackValue, v)
  if isNotNil(v) then return v end
  return fallbackValue
end)

_G.equalsBy = curryN(3, function(comparator, a, b)
  if (a == b) then return true end

  if isNotTable(a) or isNotTable(b) then return false end

  local isShallowEquals = true
  local iterated = false

  forEach(function(value, key)
    iterated = true
    if not comparator(value, b[key]) then
      isShallowEquals = false
      return stop
    end
  end, a)

  forEach(function(value, key)
    iterated = true
    if not comparator(value, a[key]) then
      isShallowEquals = false
      return stop
    end
  end, b)

  if not iterated then return true end
  return isShallowEquals
end)

_G.notEqualsBy = curryN(2, function(comparator, a, b)
    return not equalsBy(comparator, a, b)
end)

_G.equals = equalsBy(identical)
_G.notEquals = notEqualsBy(identical)

_G.deepEquals = curryN(2, function(a, b)
  return equalsBy(deepEquals, a, b)
end)

_G.notDeepEquals = curryN(2, function(a, b)
  return not equalsBy(notDeepEquals, a, b)
end)

_G.both = curryN(3, function(predicate1, predicate2, value)
  return Boolean(predicate1(value) and predicate2(value))
end)

_G.either = curryN(3, function(predicate1, predicate2, value)
  return Boolean(predicate1(value) or predicate2(value))
end)

_G.allPass = curryN(2, function(predicates, value)
  local reducer = function(acc, p) return acc and p(value) end
  return reduce(reducer, true, predicates)
end)

_G.anyPass = curryN(2, function(predicates, value)
  local reducer = function(acc, p) return acc or p(value) end
  return reduce(reducer, false, predicates)
end)

_G.identity = function(...) return ... end

_G.noop = function() end

_G.always = function(...)
  local args = pack(...)
  return function()
    return unpack(args)
  end
end

_G.const = always

_G.tap = function(f)
  return function(...)
    f(...)
    return ...
  end
end

_G.method = function(name, ...)
  local args = pack(...)

  return function(obj)
    return obj[name](obj, unpack(args))
  end
end

_G.callMethod = method

_G.add = curryN(2, function(a, b) return a + b end)
_G.sub = curryN(2, function(a, b) return b - a end)
_G.multiply = curryN(2, function(a, b) return a * b end)
_G.divide = curryN(2, function(a, b) return a / b end)
_G.divideBy = flip(divide)

_G.inc = add(1)
_G.dec = add(-1)

_G.isOdd = function(x)
  return Boolean(x % 2)
end

_G.isEven = complement(isOdd)

local a = byte('a')
local A = byte('A')
local z = byte('z')
local Z = byte('Z')

_G.isAlphaMin = function(v)
  if not isString(v) then return false end
  local code = byte(v)
  return code >= a and code <= z
end

_G.isAlphaMaj = function(v)
  if not isString(v) then return false end
  local code = byte(v)
  return code >= A and code <= Z
end

_G.isAlpha = either(isAlphaMin, isAlphaMaj)
_G.isAlphaNum = either(isStringIsNumeric, isAlpha)

-- TABLE FUNCTIONS

_G.compact = function(t)
  if isString(t) then return t end

  local ret = {}
  local i = 0

  forEach(function(v, k)
    if isNil(v) then return nil end
    if isNumber(k) then
      i = i + 1
      ret[i] = v
    else
      ret[k] = v
    end
  end, t)

  if t.n then ret.n = i end

  return ret
end

_G.reverse = function(t)
  if isString(t) then return string.reverse(t) end

  local ret = {}
  ret.n = t.n

  objForEach(function(v, k)
    ret[k] = v
  end, t)

  local tlen = length(t)
  local i = 1

  while i <= tlen do
    ret[tlen - (i - 1)] = t[i]
    i = i + 1
  end

  return ret
end

_G.forEach = curryN(2, function(f, t)
  if isString(t) then
    for i=1, #t do
      local c = string.sub(t, i, i)
      if f(c, i) == stop then return nil end
    end
    return nil
  end

  for k, v in pairs(t) do
    if notIdentical(k, 'n') then
      if f(v, k) == stop then return nil end
    end
  end
end)

_G.forEachIndexed = curryN(2, function(f, t)
  if isString(t) then
    return forEach(f, t)
  end

  for k, v in pairs(t) do
    if (isNumber(k)) then
      if f(v, k) == stop then return nil end
    end
  end
end)

_G.objForEach = curryN(2, function(f, t)
  for k, v in pairs(t) do
    if isNotNumber(k) then
      if f(v, k) == stop then return nil end
    end
  end
end)

_G.forEachRight = curryN(2, function(f, t)
  if isString(t) then
    for i=#t,1,-1 do
      local c = string.sub(t, i, i)
      if f(c, i) == stop then return nil end
    end
    return nil
  end

  t = compact(t)
  local tlen = length(t)

  for i=tlen,1,-1 do
    if f(t[i], i) == stop then return nil end
  end
end)

_G.forEachLast = forEachRight

_G.forEachIndexedRight = curryN(2, function(f, t)
  return forEachRight(function(v, k)
    return f(v, k)
  end, t)
end)

_G.forEachIndexedLast = forEachIndexedRight

local mapString = function(f, str)
  local ret = ''

  forEach(function(v)
    ret = ret .. f(v)
  end, str)

  return ret
end

_G.map = curryN(2, function(f, t)
  if isNull(t) then return null end
  if isString(t) then return mapString(f, t) end
  if isFunction(t.map) then return t:map(f) end

  local ret = {}
  ret.n = t.n

  forEach(function(v, k)
    ret[k] = f(v)
  end, t)

  return ret
end)

_G.mapIndexed = curryN(2, function(f, t)
  if isNull(t) then return null end
  if isString(t) then return mapString(f, t) end

  local ret = {}
  ret.n = t.n

  forEach(function(v, k)
    ret[k] = f(v, k)
  end, t)

  return ret
end)

_G.deepMap = curryN(2, function(f, t)
  if isTable(t) then return map(deepMap(f), t) end
  return f(t)
end)

_G.pluck = curryN(2, function(k, t)
  return map(prop(k), t)
end)

local filterString = function(predicate, str)
  local ret = ''

  forEach(function(value, key)
    if predicate(value, key) then
      ret = ret .. value
    end
  end, str)

  return ret
end

_G.filter = curryN(2, function(predicate, t)
  if isNull(t) then return null end
  if isString(t) then return filterString(predicate, t) end

  local ret = {}
  forEach(function(value, key)
    if predicate(value, key) then
      ret[key] = value
    end
  end, t)

  if type(t.n) == 'number' then
    ret.n = length(ret)
  end

  return compact(ret)
end)

_G.reject = curryN(2, function(predicate, t)
  return filter(complement(predicate), t)
end)

_G.reduce = curryN(3, function(reducer, initialAcc, t)
  local acc = initialAcc
  forEach(function(value, key)
    acc = reducer(acc, value, key)
  end, t)
  return acc
end)

_G.find = curryN(2, function(predicate, t)
  local foundValue = nil

  forEach(function(v, k)
    if predicate(v, k) then
      foundValue = v;
      return stop
    end
  end, t)

  return foundValue
end)

_G.findKey = curryN(2, function(predicate, t)
  local foundKey = nil

  forEach(function(v, k)
    if predicate(v, k) then
      foundKey = k
      return stop
    end
  end, t)

  return foundKey
end)

_G.findIndex = findKey

_G.findLast = curryN(2, function(predicate, t)
  local foundValue = nil

  forEachRight(function(v, k)
    if predicate(v, k) then
      foundValue = v
      return stop
    end
  end, t)

  return foundValue
end)

_G.findRight = findLast

_G.findLastKey = curryN(2, function(predicate, t)
  local foundKey = nil

  forEachRight(function(v, k)
    if predicate(v, k) then
      foundKey = k
      return stop
    end
  end, t)

  return foundKey
end)

_G.findLastIndex = findLastKey

_G.findByKey = curryN(2, function(predicate, t)
  return find(function(_, k)
    return predicate(k)
  end, t)
end)

_G.remove = curryN(2, function(v, t)
  local k = findKey(identical(v), t)
  if not k then return t end

  return removeProp(k, t)
end)

_G.removeLast = curryN(2, function(v, t)
  local k = findLastKey(identical(v), t)
  if not k then return t end

  return removeProp(k, t)
end)

_G.clone = map(identity)
_G.deepClone = deepMap(identity)

_G.times = curryN(2, function(f, n)
  local t = {}

  for i=1,n do
   table.insert(t, f(i))
  end

  return t
end)

------ Sorts ------
_G.sortWith = curryN(2, function(comp, t)
  local ret = clone(t)
  table.sort(ret, comp)
  return ret
end)

_G.sort = sortWith(flip(lt))
_G.sortDesc = sortWith(flip(gt))

_G.sortByWith = curryN(3, function(comp, getter, t)
  return sortWith(function(valA, valB)
    return comp(getter(valA), getter(valB))
  end, t)
end)

_G.sortBy = sortByWith(flip(lt))
_G.sortDescBy = sortByWith(flip(gt))
-------------------


-------------------
--  TIMER UTILS  --
-------------------
_G.setTimeout = function(cb, ms)
  ms = ms or 0
  local sec = ms / 1000
  return require('event').timer(sec, cb, 1)
end

_G.setImmediate = function(cb)
  return setTimeout(cb, 0)
end

_G.clearTimeout = function(...)
  return require('event').cancel(...)
end

_G.setInterval = function(cb, ms)
  ms = ms or 0
  local sec = ms / 1000
  return require('event').timer(sec, cb, math.huge)
end

_G.clearInterval = clearTimeout

-------------------


-----------------------------
--  DEBUG/PARSE/STRINGIFY  --
-----------------------------

local function dumpTable(tbl, indent)
  if not (type(tbl) == 'table') then
    print(tbl)
    return nil
  end
  if isEmpty(tbl) then
    print('{}')
    return nil
  end
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    local formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" and isNotEmpty(v) then
      print(formatting)
      dumpTable(v, indent+1)
    else
      print(formatting .. tostring(v))
    end
  end
end

_G.dump = function(...)
  local args = pack(...)

  forEach(function(arg)
    dumpTable(arg)
  end, args)

  return ...
end

_G.serialize = function(...)
  return require('serialization').serialize(...)
end

_G.stringify = serialize

_G.unserialize = function(...)
  return require('serialization').unserialize(...)
end
_G.parse = unserialize

_G.safeParse = function(x)
  if isString(x) then
    return parse(x)
  else
    return nil
  end
end

_G.printError = function(...)
  local args = pack(...)
  local nbArgs = length(args)
  local err = '';

  forEach(function(arg, k)
    err = err .. String(arg)
    if k < nbArgs then
      err = err .. '\t'
    end
  end, args)

  io.stderr:write(err .. '\n')
end

_G.printErr = printError

_G.printExit = function(...)
  printError(...)
  require('os').exit(1)
end

_G.printExitSuccess = function(...)
  print(...)
  require('os').exit(0)
end

-- -----------------------------

-- ------------------
-- --  COROUTINES  --
-- ------------------
_G.yield = coroutine.yield

-- -------------------------
-- --  monadic try/catch  --
-- -------------------------

--- @class Try
-- @description try/catch as a monad
-- TODO: flatMap (join) method
local Try = {}
Try.__index = Try
Try.__tostring = always('Try')

_G.try = setmetatable({}, Try)

function Try:__call(...)
  local fxs = pack(...)

  local tryProperties = reduce(function(state, maybeFx)
    local result = { maybeFx }
    local status = state._status

    if not status then return state end

    if isFunction(maybeFx) then
      local callResult = pack(pcall(maybeFx))
      status = first(callResult)
      result = tail(callResult)
    end

    if not status then
      return { _status=false, _result=result }
    end

    return { _status=true, _result=concat(state._result, result) }
  end, { _status=true, _result={} }, fxs)

  return setmetatable(tryProperties, Try)
end

function Try:map(callback)
  if self._status then
    callback = callback or identity
    return try(function()
      return callback(unpack(self._result))
    end)
  end
  return self
end

function Try:catch(callback)
  if not self._status then
    callback = callback or identity
    return try(function()
      return callback(unpack(self._result))
    end)
  end
  return self
end

function Try:tap(callback)
  callback = callback or identity
  return self:map(function(...)
    callback(...)
    return ...
  end)
end

function Try:extract()
  if not self._status then
    error(unpack(self._result))
  end
  return unpack(self._result)
end

function Try:get()
  return self:extract()
end

function Try:wrapStatus()
  if self._status then
    return self:map(function(...) return true, ... end)
  end

  return self:catch():map(function(...) return false, ... end)
end

function Try:pack()
  return self:map(pack)
end

function Try:unpack()
  return self:map(unpack)
end

-- -------------------------
-- --  monadic maybe  ------
-- -------------------------

-- _G.just = arrayOf
-- _G.none = function() return null end
-- _G.maybe = function(x)
--   if isNotNil(x) then return just(x) end
--   return null
-- end

_G.isMaybe = function(m)
  return Boolean(m and isTable(m) and m._data and isTable(m._data))
end

local Maybe = {}
Maybe.__index = Maybe

function Maybe:__tostring()
  dump(self._data)
  if isEmpty(self._data) then return 'None' end
  return 'Just(' .. join(', ', self._data) .. ')'
end

_G.Maybe = setmetatable({}, Maybe)

function Maybe:__call(...)
  local noneFound = false;
  local data = {}

  forEach(function(maybeMaybe)
    local value = { maybeMaybe }

    if isMaybe(maybeMaybe) then
      value = maybeMaybe:pack():extract()
    end

    if isEmpty(value) then
      noneFound = true
      return stop
    end

    data = concat(data, value)
  end, pack(...))

  if noneFound then
    return none
  end

  return setmetatable({ _data=data }, Maybe)
end

_G.maybe = setmetatable({}, Maybe)
_G.none = setmetatable({ _data={} }, Maybe)
_G.just = maybe

function Maybe:map(callback)
  callback = callback or identity
  if isEmpty(self._data) then
    return self
  end

  return maybe(callback(unpack(self._data)))
end

function Maybe:tap(callback)
  callback = callback or identity
  return self:map(function(...)
    callback(...)
    return ...
  end)
end

function Maybe:extract()
  return unpack(self._data)
end

function Maybe:get()
  return self:extract()
end

function Maybe:defaultTo(...)
  if isEmpty(self._data) then
    return maybe(...)
  end

  return self
end

function Maybe:fallbackTo(...)
  return self:defaultTo(...)
end

function Maybe:flatMap(callback)
  if isEmpty(self._data) then
    return self
  end

  return maybe(callback(unpack(self._data)))
end

function Maybe:join(callback)
  return self:flatMap(callback)
end

function Maybe:concat(...)
  return maybe(...)
end

function Maybe:pack()
  return self:map(pack)
end

function Maybe:unpack()
  return self:map(unpack)
end

-- -------------------------
-- --  free monad  ---------
-- -------------------------
-- ! for now it works only with the maybe monad

-- an attempt to make a do notation style with coroutines ;-)
_G.Do = function(coroutineDefinition)
  local co = coroutine.create(coroutineDefinition)
  local shouldContinue = true

  local monad = none

  while(shouldContinue) do
    shouldContinue, monad = coroutine.resume(co, monad:extract())
    monad = maybe(monad)

    local packedValues = monad:pack():extract()
    if shouldContinue and isEmpty(packedValues) then
      shouldContinue = false
    elseif shouldContinue and coroutine.status(co) == 'dead' then
      shouldContinue = false
    end
  end

  return monad
end
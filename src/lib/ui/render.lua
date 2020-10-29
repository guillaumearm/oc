local colors = require('colors')
local c = require('component')
local gpu = c.gpu

function getCurrentStyle()
  return {
    color=gpu.getForeground(),
    backgroundColor=gpu.getBackground()
  }
end

local stateStyle = getCurrentStyle()
local defaultStyle = clone(stateStyle)

function getHexaColor(color)
  if color == nil then return nil end

  if isString(color) then
    local paletteIndex = colors[color]
    if paletteIndex == nil then error('ui: bad color string value: ' .. String(color)) end
    return gpu.getPaletteColor(paletteIndex)
  end

  if color >= 1 and color <= 16 then
    return gpu.getPaletteColor(color)
  end

  return color
end

------------------------------------------------------------------------------------------------

function renderPrimitive(x, y, value, parentStyle, style)
  style = merge(parentStyle, style or {})

  local newColor = getHexaColor(style.color)
  local newBgColor = getHexaColor(style.backgroundColor)

  local colorChanged = isNotNil(newColor) and notEquals(stateStyle.color, newColor)
  local bgColorChanged = isNotNil(newBgColor) and notEquals(stateStyle.backgroundColor, newBgColor)

  if colorChanged then
    gpu.setForeground(newColor)
    stateStyle.color = newColor
  end
  if bgColorChanged then
    gpu.setBackground(newBgColor)
    stateStyle.backgroundColor = newBgColor
  end

  gpu.set(x, y, value)

  return { height=1, width=length(value) }
end

------------------------------------------------------------------------------------------------

function renderElement(elem, x, y, parentStyle, style, registerEvent)
  x = x or 1
  y = y or 1
  parentStyle = merge(parentStyle or defaultStyle, style or {})

  if isString(elem) then
    return renderPrimitive(x, y, elem, parentStyle, style)
  end

  local stateDim = { width=0, height=0 }
  local state = { x=x, y=y }

  forEach(function(line)
    stateDim.height = stateDim.height + line.height
    if stateDim.width < line.width then
      stateDim.width = line.width
    end

    state.x = x

    forEach(function(subElem)
      local elemDim = renderElement(subElem, state.x, state.y, parentStyle, subElem.style, registerEvent)
      state.x = state.x + elemDim.width
    end, line.content)

    state.y = state.y + line.height
  end, elem.content)

  if elem.onClick then
    registerEvent(elem.onClick, x, y, stateDim.width, stateDim.height)
  end

  return stateDim
end

------------------------------------------------------------------------------------------------

function render(elem, style, x, y, registerEvent)
  local rendered = false
  x = x or 1
  y = y or 1
  registerEvent = registerEvent or noop
  style = merge(defaultStyle, style or {})

  function prepareScreen()
    gpu.setForeground(getHexaColor(style.color))
    gpu.setBackground(getHexaColor(style.backgroundColor))
    stateStyle = getCurrentStyle()

    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, ' ')
  end

  local previousRenderedElement = nil

  function paint(e)
    if not rendered then
      rendered = true
      prepareScreen()
    end

    e = e or elem
    local prev = previousRenderedElement

    local dimChanged = e and prev and (prev.width > e.width or prev.height > e.height)
    local shapeChanged = e and prev and e.shape ~= prev.shape

    if not e or dimChanged or shapeChanged then
      -- local currentStyle = getCurrentStyle()
      gpu.setForeground(getHexaColor(style.color))
      gpu.setBackground(getHexaColor(style.backgroundColor))
      gpu.fill(x, y, prev.width, prev.height, ' ')
      gpu.setForeground(stateStyle.color)
      gpu.setBackground(stateStyle.backgroundColor)
    end

    if e then
      local elementStyle = ternary(isString(e), nil, e.style)
      renderElement(e, x, y, style, elementStyle, registerEvent);
      previousRenderedElement = e
    end
  end

  if e then paint(e) end
  return paint
end

------------------------------------------------------------------------------------------------

return render;
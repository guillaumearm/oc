local colors = require('colors')
local c = require('component')
local gpu = c.gpu

local function getCurrentStyle()
  return {
    color=gpu.getForeground(),
    backgroundColor=gpu.getBackground()
  }
end

local stateStyle = getCurrentStyle()
local defaultStyle = clone(stateStyle)

local function getHexaColor(color)
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

local function renderPrimitive(x, y, value, parentStyle, style)
  style = assign(parentStyle, style or {})

  local newColor = getHexaColor(style.color or parentStyle.color)
  local newBgColor = getHexaColor(style.backgroundColor or parentStyle.backgroundColor)

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

local function renderElement(elem, x, y, parentStyle, style, registerEvent)
  x = x or 1
  y = y or 1
  parentStyle = assign(parentStyle or defaultStyle, style or {})

  if isString(elem) then
    return renderPrimitive(x, y, elem, parentStyle, style)
  end

  if elem.onClick or elem.onClickOutside then
    registerEvent(elem, x, y, elem.width, elem.height)
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

  return stateDim
end

------------------------------------------------------------------------------------------------

local function render(_, _, x, y, registerEvent)
  local rendered = false
  x = x or 1
  y = y or 1
  registerEvent = registerEvent or noop

  local function prepareScreen(style)
    gpu.setForeground(getHexaColor(style.color))
    gpu.setBackground(getHexaColor(style.backgroundColor))
    stateStyle = getCurrentStyle()

    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, ' ')
  end

  local previousRenderedElement = nil

  local function paint(elem)
    local elemStyle = elem and elem.style or {}
    local style = assign(defaultStyle, elemStyle)

    if not rendered then
      rendered = true
      prepareScreen(style)
    end

    local e = elem
    local prev = previousRenderedElement

    local dimChanged = e and prev and (prev.width > e.width or prev.height > e.height)
    local shapeChanged = e and prev and e.shape ~= prev.shape

    -- TODO: refactor this logic
    if not e or dimChanged or shapeChanged then
      local concernedElement = e or prev

      gpu.setForeground(getHexaColor(style.color))
      gpu.setBackground(getHexaColor(style.backgroundColor))

      if not e then
        stateStyle = getCurrentStyle()
      end

      gpu.fill(x, y, concernedElement.width, concernedElement.height, ' ')

      if e then
        gpu.setForeground(stateStyle.color)
        gpu.setBackground(stateStyle.backgroundColor)
      end
    end

    if e then
      renderElement(e, x, y, style, elemStyle, registerEvent);
      previousRenderedElement = e
    end
  end
  return paint
end

------------------------------------------------------------------------------------------------

return render;
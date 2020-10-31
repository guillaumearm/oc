local api = {}

local function getElementDimensions(elem)
  if isString(elem) then
    local width = length(elem)
    -- `P` means primitive element
    return { height=1, width=width, shape='P' .. String(width) }
  end
  return { width=elem.width, height=elem.height, shape=elem.shape }
end

local getLineDimensions = reduce(function(state, elem)
  local dim = getElementDimensions(elem)

  local lineShape = state.shape .. dim.shape

  return {
    width=state.width + dim.width,
    height=ternary(state.height < dim.height, dim.height, state.height),
    shape=lineShape
  }
end, { width=0, height=0, shape='' })

local function computeElementDimensions(elem)
  if elem.height and elem.width then return elem end

  local state = { width=0, height=0, shape='' }

  local newLines = map(function(line)
    line = line.content or line
    local lineDim = getLineDimensions(line)

    -- `|` means end of line
    state.shape = state.shape .. lineDim.shape .. '|'
    state.height = state.height + lineDim.height

    if state.width < lineDim.width then
      state.width = lineDim.width
    end

    return assign({ content=line }, { width=lineDim.width, height=lineDim.height })
  end, elem.content)

  return assign(elem, { content=newLines }, state)
end

api.createUI = computeElementDimensions

api.ui = function(view)
  return function(...)
    local element = view(...)
    return computeElementDimensions(element)
  end
end

-----------------------------------------------------------------------------------

return api
local api = {}

function getElementDimensions(elem)
  if isString(elem) then
    return { height=1, width=length(elem) }
  end
  return { width=elem.width, height=elem.height }
end

local getLineDimensions = reduce(function(state, elem)    
  local dim = getElementDimensions(elem)

  return {
    width=state.width + dim.width,
    height=ternary(state.height < dim.height, dim.height, state.height)
  }
end, { width=0, height=0 })

function computeElementDimensions(elem)
  local state = { width=0, height=0 }

  local newLines = map(function(line)
    local lineDim = getLineDimensions(line)

    state.height = state.height + lineDim.height
    if state.width < lineDim.width then
      state.width = lineDim.width
    end

    return assign({ content=line }, lineDim)
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
local initialState = { value='', cursor=1 }

local withCursorStyle = withStyle({ backgroundColor="white", color="black" })

local InputText = function(setText)
  setText = setText or NEVER

  local onKey = fromKeyDown():share()

  local onAdd = onKey
    :filterAction('key')
    :renameAction('addkey')

  local onRemoveBack = onKey
    :filterAction('backspace')
    :renameAction('removeback')

  local onSubmit = onKey
    :filterAction('enter')
    :renameAction('submit')

  local onLeft = onKey:filterAction('left')
  local onRight = onKey:filterAction('right')

  local textState = merge(
    of('init'),
    onAdd,
    onRemoveBack,
    setText:action('set'),
    onLeft,
    onRight
  )
    :scanActions({
      left=function()
        return evolve({ cursor=pipe(dec, when(isZero, const(1))) })
      end,
      right=function()
        return function(state)
          return {
            value=state.value,
            cursor=min(state.cursor + 1, length(state.value))
          }
        end
      end,
      init=function()
        return always(initialState)
      end,
      addkey=function(c)
        return function(state)
          return {
            value=insertCharAt(state.cursor, c, state.value),
            cursor=state.cursor + 1
          }
        end
      end,
      removeback=function()
        return function(state)
          return {
            value=removeCharAt(state.cursor - 1, state.value),
            cursor=max(1, state.cursor - 1)
          }
        end
      end,
      set=function(v)
        return evolve({ value=always(v), cursor=always(length(v) + 1) })
      end
    }, initialState)


  local ui = textState:map(
    function(state)
      local value = rightPad(20)(state.value)

      local strA, strB = cutString(state.cursor)(value)
      local cursorText = ensureWhitespace(first(strB))
      strB = tail(strB)

      return horizontal(strA, withCursorStyle(View(cursorText)), strB)
    end,
    View
  )

  return ui, onSubmit
end

return InputText
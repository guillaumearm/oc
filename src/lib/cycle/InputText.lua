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

  local textState = merge(
    of('init'),
    onAdd,
    onRemoveBack,
    setText:action('set')
  )
    :scanActions({
      init=function()
        return always(initialState)
      end,
      addkey=function(c)
        return evolve({ value=append(c), cursor=inc  })
      end,
      removeback=function()
        return evolve({ value=dropLast(1), cursor=dec })
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
    rightPad(20),
    View
  )

  return ui, onSubmit
end

return InputText
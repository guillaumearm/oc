local initialState = { value='', cursor=1 }

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
    setText
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
      setText=function(v)
        return evolve({ value=always(v), cursor=always(length(v) + 1) })
      end
    }, initialState)


  local ui = textState:map(
    prop('value'),
    rightPad(20),
    View
  )

  return ui, onSubmit
end

return InputText
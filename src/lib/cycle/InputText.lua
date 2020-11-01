local initialState = { value='', cursor=1 }

local InputText = function(setText)
  setText = setText or NEVER

  print('> 1')
  local onKey = fromKeyDown():share()

  print('> 2')
  local onPrintableKey = onKey
    :filterAction('key')
    :renameAction('addkey')

  local onBackspace = onKey
    :filterAction('backspace')
    :renameAction('removeback')

  local onSubmit = onKey
    :filterAction('enter')
    :renameAction('submit')

  print('> 3')
  local textState = of('init'):merge(onPrintableKey, onBackspace, setText:map(createAction('setText')))
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

  print('> 4')

  local ui = textState:map(
    prop('value'),
    rightPad(20),
    View
  )

  print('> 5')

  return ui, onSubmit
end

return InputText
local initialState = { value='', cursor=1 }

local withCursorStyle = withStyle({ backgroundColor="white", color="black" })

local InputText = function(setText)
  setText = setText or NEVER

  local onClick = Subject.create()
  local onClickOutside = Subject.create()

  local selected = merge(
    onClick:mapTo(true),
    onClickOutside:mapTo(false),
    of(false)
  ):shareReplay(1)

  local onKey = fromKeyDown():when(selected):share()

  local onAddKey = onKey:filterAction('key')
  local onBackspace = onKey:filterAction('backspace')
  local onDelete = onKey:filterAction('delete')
  local onHome = onKey:filterAction('home')
  local onEnd = onKey:filterAction('end')

  local onSubmit = onKey
    :filterAction('enter')
    :renameAction('submit')

  local onLeft = onKey:filterAction('left')
  local onRight = onKey:filterAction('right')

  local textState = merge(
    of('init'),
    onLeft,
    onRight,
    onAddKey,
    onBackspace,
    onDelete,
    onHome,
    onEnd,
    setText:action('set')
  )
    :scanActions({
      init=function()
        return always(initialState)
      end,
      left=function()
        return evolve({ cursor=pipe(dec, when(isZero, const(1))) })
      end,
      right=function()
        return function(state)
          local value = state.value
          local nextCursor = state.cursor + 1

          if nextCursor > length(value) + 1 then
            nextCursor = length(value) + 1
          end

          return {
            value=value,
            cursor=nextCursor
          }
        end
      end,
      key=function(c)
        return function(state)
          return {
            value=insertCharAt(state.cursor, c, state.value),
            cursor=state.cursor + 1
          }
        end
      end,
      backspace=function()
        return function(state)
          return {
            value=removeCharAt(state.cursor - 1, state.value),
            cursor=max(1, state.cursor - 1)
          }
        end
      end,
      delete=function()
        return function(state)
          return {
            value=removeCharAt(state.cursor, state.value),
            cursor=state.cursor
          }
        end
      end,
      home=function()
        return evolve({ cursor=const(1) })
      end,
      ['end']=function()
        return function(state)
          return {
            value=state.value,
            cursor=length(state.value) + 1
          }
        end
      end,
      set=function(v)
        return evolve({ value=always(v), cursor=always(length(v) + 1) })
      end
    }, initialState)


  local cursorIsVisible = selected:switchMap(function(isSelected)
    if not isSelected then
      return of(false)
    end

    return interval(500)
      :scan(function(state) return not state end, true)
      :startWith(true)
  end)

  local ui = textState:combineLatest(cursorIsVisible):map(
    function(state, showCursor)
      local cursor = state.cursor
      local value = rightPad(20)(state.value)

      if not showCursor then
        if cursor == length(value) + 1 then
          return View(value .. ' ')
        end

        return View(value)
      end

      local strA, strB = cutString(cursor)(value)
      local cursorText = ensureWhitespace(first(strB))
      strB = tail(strB)

      return horizontal(strA, withCursorStyle(View(cursorText)), strB)
    end,
    withClick(onClick),
    withClickOutside(onClickOutside)
  )

  return ui, onSubmit
end

return InputText
local Button = function(text, onClick)
  text = isObservable(text) and text or of(text)
  onClick = onClick or Subject.create()

  local elem = text:map(View)

  local highlighted = of(false):concat(mergeAll(
    onClick:mapTo(true),
    onClick:delay(100):mapTo(false)
  ))

  return combineLatest(highlighted, elem)
    :map(function(h, e)
      if h then
        return withStyle({ color="black", backgroundColor="white" })
      end

      return e
    end)
end

return Button

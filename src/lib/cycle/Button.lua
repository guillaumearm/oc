local defaultHighlightedEnhancer = withStyle({ color="black", backgroundColor="white" })

local Button = function(text, onClick, enhancer, highlightedEnhancer)
  enhancer = enhancer or identity
  highlightedEnhancer = highlightedEnhancer or defaultHighlightedEnhancer
  text = isObservable(text) and text or of(text)
  onClick = onClick or Subject.create()

  local elem = text:map(View):map(withScopedClick(onClick), enhancer)

  local highlighted = of(false):concat(mergeAll(
    onClick:mapTo(true),
    onClick:debounce(200):mapTo(false)
  ))

  return combineLatest(highlighted, elem)
    :map(function(h, e)
      if h then
        return highlightedEnhancer(e)
      end

      return e
    end)
end

return Button

local getList = function(elements, nbDisplayedItems, scrollPosition)
  local scrolledElems = drop(scrollPosition - 1, elements);
  return take(nbDisplayedItems, scrolledElems)
end

local DEFAULT_NB_DISPLAYED = 5

local ListScroll = function(elems_, nbDisplayed_, onScroll_)
  nbDisplayed_ = nbDisplayed_ or of(DEFAULT_NB_DISPLAYED)
  onScroll_ = onScroll_ or NEVER
  local onScrollUp_ = onScroll_:pluck('type'):filter(identical(1)):mapTo('scrollup')
  local onScrollDown_ = onScroll_:pluck('type'):filter(identical(-1)):mapTo('scrolldown')

  local nbElems_ = elems_:map(length)

  local scrollPosition_ = merge(onScrollUp_, onScrollDown_)
    :map(fst)
    :with(nbDisplayed_, nbElems_)
    :scanActions({
      scrollup=function()
        return when(gt(1), dec)
      end,
      scrolldown=function(nbDisplayed, nbElems)
        return function(scrollPosition)
          if nbDisplayed + scrollPosition <= nbElems then
            return scrollPosition + 1
          end
          return scrollPosition
        end
      end
    }, 1)
    :startWith(1)
    :distinctUntilChanged()

  return combineLatest(elems_, nbDisplayed_, scrollPosition_)
    :map(getList):filter()
end

return ListScroll
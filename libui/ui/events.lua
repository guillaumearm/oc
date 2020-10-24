local event = require('event')

local init = function()
  return 'ui', '@init'
end

function runEvents(events, reducer, handler)
  reducer = reducer or noop
  handler = handler or noop
  events = events or {}

  local prevState = nil
  local state = reducer(prevState, init());
  handler(prevState, state, init())

  while true do
    local eventArgs = pack(event.pullMultiple('interrupted', unpack(events)));
    local eName = head(eventArgs)
    local secondArg = prop(2, eventArgs)
    local restEventArgs = tail(eventArgs)

    prevState = state
    state = reducer(state, eName, unpack(restEventArgs))
    handler(prevState, state, eName, unpack(restEventArgs))

    local shouldStop = eName == 'ui' and secondArg == '@stop'
    if eName == 'interrupted' or shouldStop then break; end
  end
end

return runEvents
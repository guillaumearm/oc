local event = require('event')

local init = function()
  return 'ui', '@init'
end

function runEvents(events, updater, handler)
  updater = updater or always(identity)
  handler = handler or noop
  events = events or {}

  local prevState = nil
  local state = updater(init())(prevState);

  handler(prevState, state, init())

  while true do
    local eventArgs = pack(event.pullMultiple('interrupted', unpack(events)));
    local eName = head(eventArgs)
    local secondArg = prop(2, eventArgs)
    local restEventArgs = tail(eventArgs)

    prevState = state
    state = updater(eName, unpack(restEventArgs))(state)
    handler(prevState, state, eName, unpack(restEventArgs))

    local shouldStop = eName == 'ui' and secondArg == '@stop'
    if eName == 'interrupted' or shouldStop then break; end
  end
end

return runEvents
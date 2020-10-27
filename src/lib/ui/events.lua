local event = require('event')

local init = function()
  return 'ui', '@init'
end

function runEvents(events, updater, handler)
  updater = updater or always(identity)
  handler = handler or noop
  events = events or {}

  local prevState = nil
  local state, fx = updater(init())(prevState);

  if fx then
    fx(prevState, state, init())
  end
  
  handler(prevState, state, init())

  while true do
    local eventArgs = pack(event.pullMultiple('interrupted', unpack(events)));
    local eName = head(eventArgs)
    local secondArg = prop(2, eventArgs)
    local restEventArgs = tail(eventArgs)

    prevState = state
    state, fx = updater(eName, unpack(restEventArgs))(state)

    if fx then
      fx(prevState, state, eName, unpack(restEventArgs))
    end

    handler(prevState, state, eName, unpack(restEventArgs))

    local shouldStop = eName == 'ui' and secondArg == '@stop'
    if eName == 'interrupted' or shouldStop then break; end
  end
end

return runEvents
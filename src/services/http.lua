-- Background requests; callbacks run on the main thread from http.update(), with the body (nil unless
-- the request succeeded) and the HTTP status (nil when there was no answer).
-- `parser` ("module:function") optionally turns the body into a table on the background thread,
-- for responses too big to decode on the main thread without a hitch on the device.
local http = {}

local requests, results, thread
local callbacks = {}
local nextId = 0

local function send(request, callback)
  if not thread then
    requests = love.thread.getChannel("http_requests")
    results = love.thread.getChannel("http_results")
    thread = love.thread.newThread("services/httpworker.lua")
    thread:start()
  end
  nextId = nextId + 1
  callbacks[nextId] = callback
  request.id = nextId
  requests:push(request)
end

function http.get(url, callback, parser)
  send({ url = url, parser = parser }, callback)
end

-- Saves the response to `file` (an absolute path); the callback gets true once it's there. A failed
-- download leaves no file behind.
function http.download(url, file, callback)
  send({ url = url, file = file }, callback)
end

-- Posts `body` as JSON.
function http.post(url, body, callback)
  send({ url = url, body = body }, callback)
end

function http.update()
  if not thread then return end
  local result = results:pop()
  while result do
    local callback = callbacks[result.id]
    callbacks[result.id] = nil
    callback(result.body or nil, result.status)
    result = results:pop()
  end
  local err = thread:getError()
  if err then
    error("http worker: " .. err)
  end
end

return http

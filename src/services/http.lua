-- Background GETs; callbacks run on the main thread from http.update().
local http = {}

local requests, results, thread
local callbacks = {}
local nextId = 0

function http.get(url, callback)
  if not thread then
    requests = love.thread.getChannel("http_requests")
    results = love.thread.getChannel("http_results")
    thread = love.thread.newThread("services/httpworker.lua")
    thread:start()
  end
  nextId = nextId + 1
  callbacks[nextId] = callback
  requests:push({ id = nextId, url = url })
end

function http.update()
  if not thread then return end
  local result = results:pop()
  while result do
    local callback = callbacks[result.id]
    callbacks[result.id] = nil
    callback(result.body or nil)
    result = results:pop()
  end
  local err = thread:getError()
  if err then
    error("http worker: " .. err)
  end
end

return http

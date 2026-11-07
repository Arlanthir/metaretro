-- Runs in a love.thread: downloads URLs with curl (or wget) so the UI never waits on the network.
require("love.filesystem") -- lets require() find the game's modules, for parsers
require("love.timer")
local requests = love.thread.getChannel("http_requests")
local results = love.thread.getChannel("http_results")

-- RetroAchievements answers 429 to bursts of requests (a first sync makes a couple dozen); waiting
-- a little lets them through.
local RETRY_WAITS = { 2, 4, 6 }

local function quote(text)
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

-- The body and HTTP status; the status is nil when curl isn't there.
local function curl(url)
  local pipe = io.popen(("curl -sL --max-time 20 -w '\\n%%{http_code}' %s 2>/dev/null"):format(quote(url)))
  local output = pipe and pipe:read("*a") or ""
  if pipe then pipe:close() end
  local body, status = output:match("^(.*)\n(%d%d%d)$")
  return body, tonumber(status)
end

local function wget(url)
  local pipe = io.popen(("wget -qO- -T 20 %s 2>/dev/null"):format(quote(url)))
  local body = pipe and pipe:read("*a") or ""
  if pipe then pipe:close() end
  return body
end

-- The body of a successful response, or nil.
local function fetch(url)
  local body, status
  for attempt = 1, #RETRY_WAITS + 1 do
    body, status = curl(url)
    if status ~= 429 then break end
    love.timer.sleep(RETRY_WAITS[attempt] or 0)
  end
  if not status then
    body, status = wget(url), 200
  end
  return status >= 200 and status < 300 and body ~= "" and body or nil
end

while true do
  local request = requests:demand()
  local result = fetch(request.url) or false
  if result and request.parser then
    local module, name = request.parser:match("^(.-):(.+)$")
    result = require(module)[name](result) or false
  end
  results:push({ id = request.id, body = result })
end

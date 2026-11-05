-- Runs in a love.thread: downloads URLs with curl (or wget) so the UI never waits on the network.
local requests = love.thread.getChannel("http_requests")
local results = love.thread.getChannel("http_results")

local function quote(text)
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

while true do
  local request = requests:demand()
  local url = quote(request.url)
  local pipe = io.popen(("curl -sfL --max-time 20 %s 2>/dev/null || wget -qO- -T 20 %s 2>/dev/null"):format(url, url))
  local body = pipe and pipe:read("*a") or ""
  if pipe then pipe:close() end
  results:push({ id = request.id, body = body ~= "" and body or false })
end

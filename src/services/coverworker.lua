-- Runs in a love.thread: reads and decodes cover images so the UI never blocks on the SD card.
-- Requests (what's on screen) go first; prefetches (what's likely next) fill the idle time.
require("love.filesystem")
require("love.image")

local requests = love.thread.getChannel("cover_requests")
local prefetches = love.thread.getChannel("cover_prefetches")
local results = love.thread.getChannel("cover_results")

local function load(path)
  local file = io.open(path, "rb")
  if not file then return false end
  local data = file:read("*a")
  file:close()
  local ok, decoded = pcall(love.image.newImageData, love.filesystem.newFileData(data, path))
  return ok and decoded or false
end

while true do
  local path = requests:pop() or prefetches:pop() or requests:demand(0.1)
  if path then
    results:push({ path = path, imageData = load(path) })
  end
end

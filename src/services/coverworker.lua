-- Runs in a love.thread: reads and decodes cover images so the UI never blocks on the SD card.
require("love.filesystem")
require("love.image")

local requests = love.thread.getChannel("cover_requests")
local results = love.thread.getChannel("cover_results")

while true do
  local path = requests:demand()
  local imageData
  local file = io.open(path, "rb")
  if file then
    local data = file:read("*a")
    file:close()
    local ok, decoded = pcall(love.image.newImageData, love.filesystem.newFileData(data, path))
    imageData = ok and decoded or nil
  end
  results:push({ path = path, imageData = imageData or false })
end

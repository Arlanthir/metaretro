-- Loads cover images on a background thread and keeps the most recent ones in memory.
local covers = {}

local MAX_CACHED = 24

local requests, results, thread
local cache = {} -- path -> Image, or false when the file is missing or unreadable
local order = {} -- paths from least to most recently used
local pending

local function touch(path)
  for i, cached in ipairs(order) do
    if cached == path then
      table.remove(order, i)
      break
    end
  end
  table.insert(order, path)
  while #order > MAX_CACHED do
    local evicted = table.remove(order, 1)
    if cache[evicted] then cache[evicted]:release() end
    cache[evicted] = nil
  end
end

local function start()
  requests = love.thread.getChannel("cover_requests")
  results = love.thread.getChannel("cover_results")
  thread = love.thread.newThread("services/coverworker.lua")
  thread:start()
end

function covers.update()
  if not thread then return end
  local result = results:pop()
  while result do
    cache[result.path] = result.imageData and love.graphics.newImage(result.imageData) or false
    touch(result.path)
    if result.path == pending then pending = nil end
    result = results:pop()
  end
  local err = thread:getError()
  if err then
    error("cover loader: " .. err)
  end
end

-- Returns the image if loaded, false if it can't be loaded, or nil while loading.
-- Only the latest request is kept, so scrolling past many games doesn't queue them all.
function covers.get(path)
  if cache[path] ~= nil then
    touch(path)
    return cache[path]
  end
  if not thread then start() end
  if pending ~= path then
    requests:clear()
    requests:push(path)
    pending = path
  end
  return nil
end

return covers

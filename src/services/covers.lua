-- Loads cover images on a background thread and keeps the most recent ones in memory.
local covers = {}

local MAX_CACHED = 64 -- covers are kept at most MAX_SIZE px, so this stays around 25MB
-- Covers are never shown bigger than this; larger scraped images (a 640x640 one takes 1.6MB as a
-- texture) are shrunk on the GPU, which is far faster than in Lua on ARM, where LÖVE runs without JIT.
local MAX_SIZE = 320

local requests, prefetches, results, thread
local cache = {} -- path -> Image, or false when the file is missing or unreadable
local order = {} -- paths from least to most recently used
local pending
local lastPrefetch

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
  prefetches = love.thread.getChannel("cover_prefetches")
  results = love.thread.getChannel("cover_results")
  thread = love.thread.newThread("services/coverworker.lua")
  thread:start()
end

local function toTexture(imageData)
  local image = love.graphics.newImage(imageData)
  image:setFilter("linear", "linear")
  local w, h = image:getDimensions()
  local scale = MAX_SIZE / math.max(w, h)
  if scale >= 1 then return image end
  local canvas = love.graphics.newCanvas(math.floor(w * scale), math.floor(h * scale))
  canvas:setFilter("linear", "linear")
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setBlendMode("replace")
  love.graphics.draw(image, 0, 0, 0, scale, scale)
  love.graphics.pop()
  image:release()
  imageData:release()
  return canvas
end

-- Turns at most one loaded cover into a texture per frame, so a burst of prefetches never stutters.
function covers.update()
  if not thread then return end
  local result = results:pop()
  if result then
    cache[result.path] = result.imageData and toTexture(result.imageData) or false
    touch(result.path)
    if result.path == pending then pending = nil end
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

-- Queues covers that are likely to be shown next, loaded when nothing is requested. A new list
-- replaces the old one, so scrolling quickly doesn't pile up loads for games already scrolled past.
function covers.prefetch(paths)
  local wanted = {}
  for _, path in ipairs(paths) do
    if path and cache[path] == nil then table.insert(wanted, path) end
  end
  local key = table.concat(wanted, "\n")
  if key == lastPrefetch then return end
  lastPrefetch = key
  if not thread then start() end
  prefetches:clear()
  for _, path in ipairs(wanted) do
    prefetches:push(path)
  end
end

return covers

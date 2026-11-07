-- Runs in a love.thread: decodes a video's picture ("video") or sound ("audio") with ffmpeg into
-- raw chunks, staying a few chunks ahead of playback. Requests are { id, path }, or "stop".
require("love.image")
require("love.sound")
local ffi = require("ffi")

local kind, buffer, a, b, c = ...
local control = love.thread.getChannel(kind .. "_control")
local output = love.thread.getChannel(kind .. "_output")

local function quote(text)
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

local chunkBytes, ffmpegArgs, wrap
if kind == "video" then
  local width, height, fps = a, b, c
  chunkBytes = width * height * 4
  -- Fixed frame rate and size, letterboxed, so playback is just one frame every 1/fps seconds.
  local filter = ("fps=%d,scale=%d:%d:force_original_aspect_ratio=decrease,pad=%d:%d:(ow-iw)/2:(oh-ih)/2")
    :format(fps, width, height, width, height)
  ffmpegArgs = "-an -vf " .. quote(filter) .. " -f rawvideo -pix_fmt rgba"
  wrap = function(data) return love.image.newImageData(width, height, "rgba8", data) end
else
  local rate, channels, samples = a, b, c
  chunkBytes = samples * channels * 2
  ffmpegArgs = ("-vn -ac %d -ar %d -f s16le"):format(channels, rate)
  wrap = function(data)
    local sound = love.sound.newSoundData(samples, rate, 16, channels)
    ffi.copy(sound:getFFIPointer(), data, #data)
    return sound
  end
end

-- Decodes `request` until it ends or another request arrives, and returns that request.
local function play(request)
  local pipe = io.popen(("ffmpeg -nostdin -loglevel error -i %s %s - 2>/dev/null"):format(quote(request.path), ffmpegArgs))
  local count, nextRequest = 0, nil
  while pipe and not nextRequest do
    local data = pipe:read(chunkBytes)
    if not data or #data < chunkBytes then break end
    while output:getCount() >= buffer and not nextRequest do
      nextRequest = control:demand(0.05)
    end
    if not nextRequest then
      output:push({ id = request.id, data = wrap(data) })
      count = count + 1
      nextRequest = control:pop()
    end
  end
  -- Closing the pipe early makes ffmpeg exit on its next write.
  if pipe then pipe:close() end
  if not nextRequest then
    output:push({ id = request.id, done = true, count = count })
  end
  return nextRequest
end

if kind == "video" then
  local pipe = io.popen("command -v ffmpeg 2>/dev/null")
  output:push({ ffmpeg = pipe and pipe:read("*l") or false })
  if pipe then pipe:close() end
end
local request = control:demand()
while true do
  if request == "stop" then
    request = control:demand()
  else
    request = play(request) or control:demand()
  end
end

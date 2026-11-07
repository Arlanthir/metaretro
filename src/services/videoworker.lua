-- Runs in a love.thread: decodes a video with ffmpeg into raw frames, staying a few frames ahead
-- of playback. Requests are { id, path }, or "stop".
require("love.image")

local width, height, fps, buffer = ...
local control = love.thread.getChannel("video_control")
local frames = love.thread.getChannel("video_frames")
local FRAME_BYTES = width * height * 4
-- Fixed frame rate and size, letterboxed, so playback is just one frame every 1/fps seconds.
local FILTER = ("fps=%d,scale=%d:%d:force_original_aspect_ratio=decrease,pad=%d:%d:(ow-iw)/2:(oh-ih)/2")
  :format(fps, width, height, width, height)

local function quote(text)
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function ffmpegPath()
  local pipe = io.popen("command -v ffmpeg 2>/dev/null")
  local path = pipe and pipe:read("*l")
  if pipe then pipe:close() end
  return path
end

-- Decodes `request` until the video ends or another request arrives, and returns that request.
local function play(request)
  local pipe = io.popen(("ffmpeg -nostdin -loglevel error -i %s -an -vf %s -f rawvideo -pix_fmt rgba - 2>/dev/null")
    :format(quote(request.path), quote(FILTER)))
  local count, nextRequest = 0, nil
  while pipe and not nextRequest do
    local data = pipe:read(FRAME_BYTES)
    if not data or #data < FRAME_BYTES then break end
    while frames:getCount() >= buffer and not nextRequest do
      nextRequest = control:demand(0.05)
    end
    if not nextRequest then
      frames:push({ id = request.id, image = love.image.newImageData(width, height, "rgba8", data) })
      count = count + 1
      nextRequest = control:pop()
    end
  end
  -- Closing the pipe early makes ffmpeg exit on its next write.
  if pipe then pipe:close() end
  if not nextRequest then
    frames:push({ id = request.id, done = true, frames = count })
  end
  return nextRequest
end

frames:push({ ffmpeg = ffmpegPath() or false })
local request = control:demand()
while true do
  if request == "stop" then
    request = control:demand()
  else
    request = play(request) or control:demand()
  end
end

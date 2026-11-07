-- Plays one video at a time, without sound. LÖVE only plays Ogg Theora and scraped videos are
-- mostly MP4, so ffmpeg decodes them on a background thread (see videoworker.lua).
local log = require("core.log")

local video = {}

video.WIDTH, video.HEIGHT, video.FPS = 320, 240, 20
local BUFFER = 6 -- frames decoded ahead, about 300KB each

local control, frames, thread
local screen -- one Image reused for every frame
local current -- { id, path, clock, shown, done, frames }
local nextId = 0

local function start()
  control = love.thread.getChannel("video_control")
  frames = love.thread.getChannel("video_frames")
  thread = love.thread.newThread("services/videoworker.lua")
  thread:start(video.WIDTH, video.HEIGHT, video.FPS, BUFFER)
end

-- The next message for the video playing now; frames left over from earlier videos are dropped.
local function nextMessage()
  local message = frames:pop()
  while message do
    if message.ffmpeg ~= nil then
      log("video: ffmpeg %s", message.ffmpeg or "not found, the TV can't play anything")
    elseif current and message.id == current.id then
      return message
    elseif message.image then
      message.image:release()
    end
    message = frames:pop()
  end
end

function video.play(path)
  if not thread then start() end
  nextId = nextId + 1
  current = { id = nextId, path = path, clock = 0, shown = 0 }
  control:push({ id = nextId, path = path })
end

function video.stop()
  if not thread then return end
  control:push("stop")
  current = nil
  nextMessage()
end

-- Shows the frame due now. When the decoder falls behind, playback waits for it instead of skipping.
function video.update(dt)
  if not thread then return end
  local err = thread:getError()
  if err then error("video worker: " .. err) end
  if not current then
    nextMessage()
    return
  end
  current.clock = current.clock + dt
  local due
  while not current.done and current.clock >= current.shown / video.FPS do
    local message = nextMessage()
    if not message then
      current.clock = current.shown / video.FPS
      break
    elseif message.done then
      current.done, current.frames = true, message.frames
      if message.frames == 0 then log("video: couldn't play %s", current.path) end
    else
      if due then due:release() end
      due = message.image
      current.shown = current.shown + 1
    end
  end
  if due then
    if screen then
      screen:replacePixels(due)
    else
      screen = love.graphics.newImage(due)
      screen:setFilter("linear", "linear")
    end
    due:release()
  end
end

-- The frame on show, or nil before the current video's first one.
function video.frame()
  return current and current.shown > 0 and screen or nil
end

-- Whether the current video has ended, and whether it failed to play at all.
function video.finished()
  return current ~= nil and current.done == true, current ~= nil and current.frames == 0
end

return video

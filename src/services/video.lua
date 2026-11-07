-- Plays one video at a time. LÖVE only plays Ogg Theora and scraped videos are mostly MP4, so
-- ffmpeg decodes the picture and the sound on two background threads (see videoworker.lua).
local log = require("core.log")

local video = {}

video.WIDTH, video.HEIGHT, video.FPS = 320, 240, 20
local FRAMES_AHEAD = 6 -- about 300KB each
local RATE, CHANNELS, SAMPLES = 44100, 2, 4096 -- sound comes in chunks of about 0.1s
local CHUNKS_AHEAD, QUEUED_CHUNKS = 4, 8
local VOLUME = 0.8

local workers -- { video = { control, output }, audio = { control, output } }
local screen -- one Image reused for every frame
local current -- { id, path, clock, shown, done, frames, sound, queued, soundDone, started }
local nextId = 0

local function startWorker(kind, ...)
  local thread = love.thread.newThread("services/videoworker.lua")
  thread:start(kind, ...)
  return { thread = thread, control = love.thread.getChannel(kind .. "_control"),
    output = love.thread.getChannel(kind .. "_output") }
end

-- The next message from a worker for the video playing now; leftovers from earlier videos are dropped.
local function nextMessage(worker)
  local message = worker.output:pop()
  while message do
    if message.ffmpeg ~= nil then
      log("video: ffmpeg %s", message.ffmpeg or "not found, the TV can't play anything")
    elseif current and message.id == current.id then
      return message
    elseif message.data then
      message.data:release()
    end
    message = worker.output:pop()
  end
end

local function stopSound()
  if current and current.sound then
    current.sound:stop()
    current.sound:release()
  end
end

function video.play(path)
  if not workers then
    workers = {
      video = startWorker("video", FRAMES_AHEAD, video.WIDTH, video.HEIGHT, video.FPS),
      audio = startWorker("audio", CHUNKS_AHEAD, RATE, CHANNELS, SAMPLES),
    }
  end
  stopSound()
  nextId = nextId + 1
  current = { id = nextId, path = path, clock = 0, shown = 0, queued = 0,
    sound = love.audio.newQueueableSource(RATE, 16, CHANNELS, QUEUED_CHUNKS) }
  current.sound:setVolume(VOLUME)
  for _, worker in pairs(workers) do
    worker.control:push({ id = nextId, path = path })
  end
end

function video.stop()
  if not workers then return end
  stopSound()
  current = nil
  for _, worker in pairs(workers) do
    worker.control:push("stop")
    nextMessage(worker)
  end
end

-- Keeps the sound queue topped up. A video without sound just plays silently.
local function feedSound()
  while not current.soundDone and current.sound:getFreeBufferCount() > 0 do
    local message = nextMessage(workers.audio)
    if not message then return end
    if message.done then
      current.soundDone = true
    else
      current.sound:queue(message.data)
      message.data:release()
      current.queued = current.queued + 1
    end
  end
end

-- Shows the frame due now. Picture and sound start together once both have something to play;
-- if the picture decoder falls behind, it waits for it instead of skipping frames.
function video.update(dt)
  if not workers then return end
  for kind, worker in pairs(workers) do
    local err = worker.thread:getError()
    if err then error(kind .. " worker: " .. err) end
  end
  if not current then
    for _, worker in pairs(workers) do nextMessage(worker) end
    return
  end

  feedSound()
  if current.started then
    current.clock = current.clock + dt
    if current.queued > 0 and not current.sound:isPlaying() then current.sound:play() end
  end
  local due
  while not current.done and current.clock >= current.shown / video.FPS do
    local message = nextMessage(workers.video)
    if not message then
      current.clock = current.shown / video.FPS
      break
    elseif message.done then
      current.done, current.frames = true, message.count
      if message.count == 0 then log("video: couldn't play %s", current.path) end
    else
      if due then due:release() end
      due = message.data
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
  if not current.started and current.shown > 0 and (current.queued > 0 or current.soundDone) then
    current.started = true
    if current.queued > 0 then current.sound:play() end
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

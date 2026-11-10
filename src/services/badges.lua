local http = require("services.http")

-- RetroAchievements badges (64px PNGs), downloaded once into the save folder's badges/, so a game's
-- list works offline afterwards. Locked achievements use the badge's greyed "_lock" version.
local badges = {}

badges.URL = "https://media.retroachievements.org/Badge/%s.png"
badges.DIR = "badges"

local images = {} -- file -> Image, or false when it can't be had
local downloading = {}
local toLoad = {} -- downloaded files waiting to become images, one per frame

local function fileFor(badge, locked)
  return ("%s/%s%s.png"):format(badges.DIR, badge, locked and "_lock" or "")
end

-- The badge's image, or nil while it's on its way (or when it can't be had).
function badges.get(badge, locked)
  if not badge then return nil end
  local file = fileFor(badge, locked)
  local image = images[file]
  if image ~= nil then return image or nil end
  if love.filesystem.getInfo(file) then
    toLoad[file] = true
  elseif not downloading[file] then
    downloading[file] = true
    love.filesystem.createDirectory(badges.DIR)
    local url = badges.URL:format(badge .. (locked and "_lock" or ""))
    http.download(url, love.filesystem.getSaveDirectory() .. "/" .. file, function(ok)
      downloading[file] = nil
      if ok then toLoad[file] = true else images[file] = false end
    end)
  end
  return nil
end

-- Turns one downloaded badge into an image per frame, so opening a list never stutters.
function badges.update()
  local file = next(toLoad)
  if not file then return end
  toLoad[file] = nil
  local ok, image = pcall(love.graphics.newImage, file)
  images[file] = ok and image or false
end

-- Lets go of the images (they're on disk for next time).
function badges.release()
  for file, image in pairs(images) do
    if image then image:release() end
    images[file] = nil
  end
  toLoad = {}
end

return badges

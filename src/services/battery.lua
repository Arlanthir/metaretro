-- The battery's charge, for the Start menu. LÖVE asks SDL; when SDL can't tell, Linux's
-- /sys/class/power_supply has it (the RG40XXV's battery is one of the folders there). Read at most
-- every REFRESH seconds, since the menu draws it every frame.
local battery = {}

battery.REFRESH = 30
battery.SYS = "/sys/class/power_supply"

local function readLine(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local line = file:read("*l")
  file:close()
  return line
end

-- The power_supply folder of type "Battery", looked up once; false when there's none.
local sysDir
local function batteryDir()
  if sysDir == nil then
    sysDir = false
    local listing = io.popen("ls -1 " .. battery.SYS .. " 2>/dev/null")
    for name in listing and listing:lines() or function() end do
      local dir = battery.SYS .. "/" .. name
      if readLine(dir .. "/type") == "Battery" and readLine(dir .. "/capacity") then
        sysDir = dir
        break
      end
    end
    if listing then listing:close() end
  end
  return sysDir
end

local function read()
  local state, percent = love.system.getPowerInfo()
  if percent then return percent, state == "charging" end
  local dir = batteryDir()
  local capacity = dir and tonumber(readLine(dir .. "/capacity"))
  if capacity then return capacity, readLine(dir .. "/status") == "Charging" end
  return nil, false
end

local percent, charging, readAt

-- The charge (0-100, or nil when the device has no battery it can read) and whether it's charging.
function battery.get()
  local now = love.timer.getTime()
  if not readAt or now - readAt >= battery.REFRESH then
    percent, charging = read()
    readAt = now
  end
  return percent, charging
end

return battery

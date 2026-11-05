-- `onChange` runs whenever the top scene changes.
local scenes = { stack = {}, onChange = function() end }

local function top()
  return scenes.stack[#scenes.stack]
end

local function call(scene, method, ...)
  if scene and scene[method] then
    return scene[method](scene, ...)
  end
end

function scenes.push(scene)
  table.insert(scenes.stack, scene)
  scenes.onChange()
  call(scene, "enter")
end

function scenes.pop()
  local scene = table.remove(scenes.stack)
  scenes.onChange()
  call(scene, "leave")
  call(top(), "resume")
end

function scenes.switch(scene)
  scenes.stack = {}
  scenes.push(scene)
end

function scenes.update(dt) call(top(), "update", dt) end
function scenes.action(name) call(top(), "action", name) end

-- Draws the top scene, and the ones below it while the scene above has `drawBelow` (overlays).
function scenes.draw()
  local first = #scenes.stack
  while first > 1 and scenes.stack[first].drawBelow do
    first = first - 1
  end
  for i = math.max(first, 1), #scenes.stack do
    call(scenes.stack[i], "draw")
  end
end

return scenes

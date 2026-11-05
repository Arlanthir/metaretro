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

function scenes.draw()
  for _, scene in ipairs(scenes.stack) do
    if scene == top() or scene.drawBelow then
      call(scene, "draw")
    end
  end
end

return scenes

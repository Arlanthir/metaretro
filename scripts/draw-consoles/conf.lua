function love.conf(t)
  t.identity = "metaretro-draw-consoles"
  -- The preview needs graphics, so a tiny window flashes up while it draws.
  t.window.width, t.window.height, t.window.vsync = 64, 64, 0
end

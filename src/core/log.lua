-- stdout is piped to tee on device, so flush every line in case the process is killed.
return function(format, ...)
  io.stdout:write("[metaretro] ", format:format(...), "\n")
  io.stdout:flush()
end

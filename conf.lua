function love.conf(t)
    t.identity = "hardware_2048" -- Save directory name
    t.version = "11.5"           -- LOVE version
    t.console = false            -- Disable console for release builds
    
    t.window.title = "NVIDIA 2048: The Hardware Ladder"
    t.window.width = 600
    t.window.height = 800
    t.window.resizable = false
    t.window.minwidth = 400
    t.window.minheight = 500
    t.window.fullscreen = false
    t.window.vsync = 1
    t.window.msaa = 4            -- Antialiasing
    t.window.depth = nil
    t.window.stencil = nil
    t.window.display = 1
end

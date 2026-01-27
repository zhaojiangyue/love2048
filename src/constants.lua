local Constants = {}

Constants.GRID_SIZE = 4
Constants.TILE_SIZE = 120
Constants.TILE_GAP = 12
Constants.BOARD_PADDING = 15

-- Color Palette (Cyberpunk / NVIDIA Green theme)
Constants.COLORS = {
    BACKGROUND = {0.1, 0.1, 0.12, 1},       -- Deep dark blue/gray
    BOARD = {0.15, 0.15, 0.18, 1},          -- Slightly lighter board
    TEXT = {0.9, 0.9, 0.9, 1},
    ACCENT = {0.46, 0.84, 0.0, 1}           -- NVIDIA Green
}

-- Hardware Tiers
Constants.TIERS = {
    [2] = { name = "GT 210", color = {0.3, 0.3, 0.3} },
    [4] = { name = "GTX 750 Ti", color = {0.35, 0.35, 0.4} },
    [8] = { name = "GTX 970", color = {0.2, 0.5, 0.2} },
    [16] = { name = "GTX 1080 Ti", color = {0.2, 0.6, 0.2} },
    [32] = { name = "RTX 2080 Ti", color = {0.2, 0.7, 0.3} },
    [64] = { name = "RTX 3090", color = {0.3, 0.8, 0.4} },
    [128] = { name = "RTX 4090", color = {0.7, 0.2, 0.2} }, -- Start getting hot/red
    [256] = { name = "A100", color = {0.8, 0.5, 0.1} },
    [512] = { name = "H100", color = {0.9, 0.1, 0.1} },
    [1024] = { name = "GB200", color = {0.5, 0.1, 0.9} },
    [2048] = { name = "Jensen's Kitchen", color = {1, 0.84, 0} } -- Gold
}

return Constants

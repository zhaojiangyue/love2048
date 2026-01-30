local Constants = {}

-- ============================================================================
-- GRID & LAYOUT
-- ============================================================================

Constants.GRID_SIZE = 4
Constants.TILE_SIZE = 120
Constants.TILE_GAP = 12
Constants.BOARD_PADDING = 15

-- Window dimensions
Constants.WINDOW_WIDTH = 600
Constants.WINDOW_HEIGHT = 700

-- ============================================================================
-- COLOR PALETTE (Cyberpunk / NVIDIA Green theme)
-- ============================================================================

Constants.COLORS = {
    BACKGROUND = {0.1, 0.1, 0.12, 1},       -- Deep dark blue/gray
    BOARD = {0.15, 0.15, 0.18, 1},          -- Slightly lighter board
    TEXT = {0.9, 0.9, 0.9, 1},
    ACCENT = {0.46, 0.84, 0.0, 1},          -- NVIDIA Green

    -- UI Elements
    HEAT_NORMAL = {0.2, 0.8, 0.3, 1},       -- Green
    HEAT_WARM = {1, 0.6, 0, 1},             -- Orange
    HEAT_HOT = {1, 0.2, 0.2, 1},            -- Red
    DLSS_ACTIVE = {0.3, 0.8, 1, 1},         -- Cyan
    DLSS_DEPLETED = {0.2, 0.2, 0.25, 1},    -- Dark gray

    -- Game Over
    GAMEOVER_OVERLAY = {0, 0, 0, 0.8},
    GAMEOVER_TEXT = {1, 0, 0, 1}
}

-- ============================================================================
-- HARDWARE TIERS
-- ============================================================================

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
    [2048] = { name = "Jensen's\nKitchen", color = {1, 0.84, 0} }, -- Gold
    -- Endless Mode Tiers (Darker backgrounds for white text visibility)
    [4096] = { name = "Quantum Core", color = {0.3, 0.3, 0.5} }, -- Dark Slate Blue
    [8192] = { name = "Dyson Swarm", color = {0.6, 0.1, 0.4} }, -- Deep Magenta
    [16384] = { name = "Multiverse\nGPU", color = {0.0, 0.4, 0.5} }, -- Deep Cyan
    [32768] = { name = "Singularity", color = {0.1, 0.0, 0.2} }, -- Void Purple
    [65536] = { name = "The Simulation", color = {0.05, 0.05, 0.05} }, -- Almost Black
}

-- ============================================================================
-- MECHANICS CONFIGURATION
-- ============================================================================

Constants.MECHANICS = {
    -- Heat Management System
    HEAT_VALUES = {
        [128] = 10,  -- RTX 4090
        [256] = 15,  -- A100
        [512] = 25,  -- H100
        [1024] = 40, -- GB200
        [2048] = 60, -- Jensen's Kitchen
        [4096] = 80,
        [8192] = 100,
        [16384] = 150,
        [32768] = 200,
        [65536] = 300
    },
    THERMAL_THRESHOLDS = {
        NORMAL = 0,
        WARM = 50,
        HOT = 75,
        THROTTLING = 90
    },
    HEAT_COOLDOWN_PER_MOVE = 1,
    THERMAL_THROTTLE_CHANCE = 0.2,  -- 20% chance to downgrade tiles at 90%+ heat
    THERMAL_SCORE_PENALTY_HOT = 0.75,      -- 25% reduction when hot
    THERMAL_SCORE_PENALTY_THROTTLING = 0.5, -- 50% reduction when throttling

    -- Neural Network Training System
    TRAINING_TRAINED_THRESHOLD = 10,        -- Moves until trained (2x score)
    TRAINING_OVERTRAINED_THRESHOLD = 20,    -- Moves until overtrained
    TRAINING_OVERTRAINED_DEADLINE = 5,      -- Moves until game over
    TRAINING_SCORE_MULTIPLIER = 2.0,        -- 2x score for trained tiles

    -- DLSS (AI Upscaling) System
    DLSS_MAX_CHARGES = 3,
    DLSS_REGEN_POINTS = 1000,  -- Points needed to regenerate 1 charge
    LQ_SPAWN_CHANCE = 0.1,     -- 10% chance to spawn LQ tiles
    DLSS_UPSCALE_MULTIPLIER = 2, -- Doubles tile value

    -- Tensor Core Cascades
    RTX_TIERS = {32, 64, 128, 256, 512, 1024, 2048},
    TENSOR_CASCADE_BOOST_MULTIPLIER = 2,  -- Adjacent tile boost amount
    TENSOR_CASCADE_BONUS_PERCENT = 0.5,   -- 50% of boosted value as bonus score

    -- Multi-GPU SLI Bridges
    SLI_BONUS_2_TILES = 1.5,  -- +50% score
    SLI_BONUS_3_TILES = 2.0,  -- +100% score
    SLI_BONUS_4_TILES = 3.0   -- +200% score (Quad-GPU achievement)
}

-- ============================================================================
-- VISUAL EFFECTS CONFIGURATION
-- ============================================================================

Constants.EFFECTS = {
    -- Particle Colors
    TENSOR_CASCADE_COLOR = {0.2, 0.9, 0.3, 1},  -- Bright green
    TRAINING_GLOW_COLOR = {0, 0.7, 1, 1},       -- Cyan
    OVERTRAINED_COLOR = {1, 0, 0, 1},           -- Red
    SLI_BRIDGE_COLOR = {0.3, 0.9, 1, 1},        -- Cyan/white
    HEAT_DISTORTION_COLOR = {1, 0.3, 0, 0.5},   -- Orange

    -- Particle Counts
    TENSOR_CASCADE_PARTICLES = 12,
    DLSS_PARTICLES = 20,
    MERGE_PARTICLES = 8,

    -- Particle Lifetimes
    TENSOR_CASCADE_LIFETIME = 1.0,
    DLSS_LIFETIME = 0.8,
    MERGE_LIFETIME = 0.6,
    HEAT_DISTORTION_LIFETIME = 1.2,
    TRAINING_SPARKLE_LIFETIME = 0.5,

    -- Animation Speeds
    TRAINING_GLOW_SPEED = 2,
    OVERTRAINED_PULSE_SPEED = 3,
    SLI_GLOW_SPEED = 2,

    -- Screen Effects
    MAX_SCREEN_SHAKE = 20,
    SCREEN_SHAKE_DECAY = 60,  -- Per second
    MERGE_SHAKE_AMOUNT = 5,
    CASCADE_SHAKE_AMOUNT = 3,

    -- Heat Overlay
    HEAT_OVERLAY_PULSE_SPEED = 2,
    HEAT_OVERLAY_ALPHA_WARM = 0.1,
    HEAT_OVERLAY_ALPHA_HOT = 0.2,
    HEAT_OVERLAY_ALPHA_THROTTLING = 0.3
}

-- ============================================================================
-- UI CONFIGURATION
-- ============================================================================

Constants.UI = {
    -- Fonts
    FONT_SIZE_TINY = 12,
    FONT_SIZE_SMALL = 14,
    FONT_SIZE_LARGE = 24,
    FONT_SIZE_HUGE = 40,

    -- Heat Meter
    HEAT_METER_WIDTH = 150,
    HEAT_METER_HEIGHT = 20,
    HEAT_METER_X = 420,
    HEAT_METER_Y = 80,

    -- DLSS Indicator
    DLSS_INDICATOR_X = 20,
    DLSS_INDICATOR_Y = 120,
    DLSS_BOLT_SPACING = 25,

    -- Animations
    TILE_POP_DURATION = 0.2,
    TILE_MOVE_DURATION = 0.15,
    TILE_MERGE_DURATION = 0.15,
    TILE_MERGE_BOUNCE = 1.1,

    -- UI Positioning
    TITLE_Y = 20,
    SCORE_Y = 80,
    BOARD_START_X = 20,
    BOARD_START_Y = 150,

    -- Hints
    HINT_Y = 650,
    HINT_FLASH_SPEED = 3
}

-- ============================================================================
-- GAME CONFIGURATION
-- ============================================================================

Constants.GAME = {
    -- Save System
    AUTO_SAVE_INTERVAL = 10,  -- Moves between auto-saves
    SAVE_VERSION = 2,          -- Current save format version

    -- Spawn Rates
    SPAWN_2_CHANCE = 0.9,     -- 90% chance to spawn 2
    SPAWN_4_CHANCE = 0.1,     -- 10% chance to spawn 4

    -- Score Thresholds (for achievements/milestones)
    SCORE_MILESTONES = {1000, 5000, 10000, 25000, 50000, 100000}
}

-- ============================================================================
-- ACHIEVEMENTS
-- ============================================================================

Constants.ACHIEVEMENTS = {
    {
        id = "first_rtx",
        name = "Entry Level RTX",
        description = "Reach RTX 2080 Ti (32)",
        threshold = 32
    },
    {
        id = "quad_gpu",
        name = "Quad-GPU Master",
        description = "Create a 4-tile SLI bridge",
        condition = "sli_4_tiles"
    },
    {
        id = "neural_expert",
        name = "Neural Network Expert",
        description = "Merge a trained tile for 2x bonus",
        condition = "training_bonus"
    },
    {
        id = "dlss_master",
        name = "DLSS Master",
        description = "Use DLSS upscaling 10 times",
        condition = "dlss_10_uses"
    },
    {
        id = "heat_survivor",
        name = "Thermal Survivor",
        description = "Win a game with heat >90%",
        condition = "win_at_90_heat"
    },
    {
        id = "cascade_chain",
        name = "Cascade Chain Reaction",
        description = "Trigger 3 tensor cascades in one turn",
        condition = "cascade_3_in_turn"
    },
    {
        id = "jensens_kitchen",
        name = "Jensen's Kitchen",
        description = "Reach the ultimate tile (2048)",
        threshold = 2048
    }
}

-- ============================================================================
-- TUTORIAL MESSAGES
-- ============================================================================

Constants.TUTORIAL = {
    {
        trigger = "first_move",
        message = "Merge identical GPU tiles to upgrade! Arrow keys to move."
    },
    {
        trigger = "first_lq_tile",
        message = "Low-Quality tile detected! Press SPACE to use DLSS upscaling."
    },
    {
        trigger = "first_rtx_merge",
        message = "RTX merge! Tensor Cores boosted an adjacent tile!"
    },
    {
        trigger = "first_trained_tile",
        message = "Tile is trained! Merge for 2x score bonus (cyan glow)."
    },
    {
        trigger = "first_overtrained",
        message = "WARNING: Neural network overtraining! Merge within 5 moves!"
    },
    {
        trigger = "heat_warning",
        message = "System temperature critical! Cool down by making moves."
    },
    {
        trigger = "sli_bridge_formed",
        message = "SLI Bridge detected! Merge for bonus multiplier!"
    }
}

return Constants


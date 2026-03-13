-- core/settings.lua
SETTINGS = {
    -- 4096 * 4096 = 16MB (Very safe for VM)
    -- 8192 * 8192 = 64MB (High end)
    GRID_BUFFER_SIZE = 4096,

    CELL_SIZE = 1, -- Zoom level (higher = less GPU strain)
    CAMERA_SPEED = 10000,

    SIDEBAR_WIDTH = 250,
    TOPBAR_HEIGHT = 50,

    KEYS = {
        UP    = "w",
        DOWN  = "s",
        LEFT  = "a",
        RIGHT = "d",
        ERASE = "lshift",
        FULLSCREEN = "f"
    }
}

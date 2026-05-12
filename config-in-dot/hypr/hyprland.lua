--   ▖▖▖▖▄▖▄▖▖ ▄▖▖ ▖▄   ▄▖▄▖▖ ▖▄▖▄▖▄▖   --
--   ▙▌▌▌▙▌▙▘▌ ▌▌▛▖▌▌▌  ▌ ▌▌▛▖▌▙▖▐ ▌    --
--   ▌▌▐ ▌ ▌▌▙▖▛▌▌▝▌▙▘  ▙▖▙▌▌▝▌▌ ▟▖▙▌   --
--                                  -DK --
                                
-- environment variables
--source = ~/.config/hypr/environment.conf
require("environment")

-- nvidia gpu settings
-- source = ~/.config/hypr/nvidia.conf
require("nvidia")

-- monitor configuration
-- source = ~/.config/hypr/monitors.conf
require("monitors")

-- programs and launcher config
-- source = ~/.config/hypr/programs.conf
require("programs")

-- applications to start on login
-- source = ~/.config/hypr/autostart.conf
require("autostart")

-- colors from pywal theme
-- source = ~/.cache/wal/hyprland-pywal.conf
require("colors")

-- window style and layout rules
-- source = ~/.config/hypr/style-layout.conf
require("style-layout")

-- input devices and settings
-- source = ~/.config/hypr/input.conf
require("input")

-- keyboard shortcuts
-- source = ~/.config/hypr/keybinds.conf
require("keybinds")

-- window rules for specific apps
-- source = ~/.config/hypr/windowrules.conf
require("windowrules")

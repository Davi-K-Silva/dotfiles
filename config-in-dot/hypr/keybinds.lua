-------------------------
------ KEYBINDINGS ------
-------------------------
local terminal = "kitty"
local fileManager = "kitty yazi"
local menu = "wofi --show drun"
local shape_theme = "~/Desktop/shape-theme/theme-menu.sh"
local shape_theme_fill = "~/Desktop/shape-theme/change-theme-menu-wallcrop.sh"

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Terminal
hl.bind(mainMod .. " + Return",        hl.dsp.exec_cmd("[float; size 800 500;move 1100 70] " .. terminal))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(terminal))

-- Window management
hl.bind(mainMod .. " + X",           hl.dsp.window.close())
hl.bind(mainMod .. " + M",           hl.dsp.exec_cmd("hyprctl dispatch \"hl.dsp.exit()\""))
hl.bind(mainMod .. " + V",           hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + P",   hl.dsp.window.pseudo())
hl.bind(mainMod .. " + SHIFT + J",   hl.dsp.layout("togglesplit")) -- dwindle only

-- Exec shortcuts
hl.bind(mainMod .. " + E",           hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B",           hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + SPACE",       hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + N",           hl.dsp.exec_cmd("qs ipc call notifications toggle"))
hl.bind(mainMod .. " + W",           hl.dsp.exec_cmd(shape_theme))
hl.bind(mainMod .. " + SHIFT + W",   hl.dsp.exec_cmd(shape_theme_fill))
hl.bind(mainMod .. " + SHIFT + L",   hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + Z",           hl.dsp.exec_cmd("hexecute"))
--hl.bind(mainMod .. " + Print",       hl.dsp.exec_cmd("region=$(slurp); sleep 0.5; grim -g \"$region\" ~/$(date +'%s_grim.png')"))
hl.bind(mainMod .. " + Print",         hl.dsp.exec_cmd("hyprpicker -r -z & sleep 0.1 && grim -g \"$(slurp -d)\" - | wl-copy; pkill hyprpicker"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("hyprpicker -r -z & sleep 0.1 && region=$(slurp -d); grim -g \"$region\" ~/$(date +'%s_grim.png'); pkill hyprpicker"))
hl.bind(mainMod .. " + ALT + Print",     hl.dsp.exec_cmd("hyprpicker -r -z & sleep 0.1 && grim -g \"$(slurp -d)\" - | tesseract stdin stdout 2>/dev/null --psm 4 | sed -E ':a;N;$!ba;s/\\n+/\\n/g' | wl-copy; pkill hyprpicker"))
hl.bind(mainMod .. " + ALT + P + Print", hl.dsp.exec_cmd("hyprpicker -r -z & sleep 0.1 && grim -g \"$(slurp -d)\" - | tesseract stdin stdout 2>/dev/null -l por --psm 4 | sed -E ':a;N;$!ba;s/\\n+/\\n/g' | wl-copy; pkill hyprpicker"))

-- Move focus with mainMod + arrow keys / vim motions
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + H",     hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L",     hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K",     hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J",     hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys for volume and LCD brightness
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

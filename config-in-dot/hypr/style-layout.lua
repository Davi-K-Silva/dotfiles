-------------------------------
------ STYLE AND LAYOUT  ------
-------------------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,
        border_size = 2,
        col = {
            active_border = { colors = { color11, "rgba(59595900)", color14 }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        }, 

        resize_on_border = false,
        allow_tearing    = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },
        blur = {
            enabled    = true,
            size       = 5,
            passes     = 3,
            vibrancy   = 2,
            contrast   = 1.5,
            brightness = 1.0,
        },
    },
})


hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    misc = {
        force_default_wallpaper = 1,
        disable_hyprland_logo   = false,
    },
})

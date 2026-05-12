-------------------------
------ WINDOWRULES ------
-------------------------

hl.window_rule({
    -- Sets the animation style for kitty
    name  = "kitty-slide-anim",
    match = { class = "kitty" },

    animation = "slide",
})

hl.window_rule({
    name  = "kitty-opacity",
    match = { class = "kitty" },

    opacity = "0.8 0.8",
})

hl.window_rule({
    name  = "vscodium-opacity",
    match = { class = "vscodium" },

    opacity = "0.9 0.9",
})

hl.window_rule({
    name  = "librepods-float-size-center",
    match = { title = "LibrePods" },

    float  = true,
    size   = { 300, 300 },
    center = true,
})

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

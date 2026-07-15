-------------------
------ INPUT ------
-------------------

hl.config({
  input = {
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
      natural_scroll = true,
    },
  },

  cursor = {
    no_hardware_cursors = true,
  },
})

hl.device({
  name = "at-translated-set-2-keyboard",
  kb_layout = "br",
})

hl.device({
  name = "dell-computer-corp-dell-universal-receiver",
  kb_layout = "br",
})

hl.device({
  name = "keychron-keychron-k2-he-keyboard",
  kb_layout = "us",
})

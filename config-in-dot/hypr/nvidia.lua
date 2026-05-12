---------------------------
------ NVIDIA TWEAKS ------
---------------------------

hl.env("LIBVA_DRIVER_NAME","nvidia")
hl.env("XDG_SESSION_TYPE","wayland")
hl.env("GDM_BACKEND","nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME","nvidia")

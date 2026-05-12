-----------------------
------ AUTOSTART ------
-----------------------

hl.on("hyprland.start", function ()
  hl.exec_cmd("hyprlock")
  hl.exec_cmd("QS_ICON_THEME=\"Cosmic\" quickshell")
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 22")
end)

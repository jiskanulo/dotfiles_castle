hs.hotkey.bind({ "cmd", "shift" }, "6", function()
  local appName = "alacritty"
  local app = hs.application.find(appName)

  if app == nil or app:isHidden() then
    hs.application.launchOrFocus(appName)
  else
    app:hide()
  end
end)

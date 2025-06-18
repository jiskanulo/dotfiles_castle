--- Launch or toggle App.
-- @see   https://www.hammerspoon.org/docs/hs.hotkey.html#bind
-- @param mods     A table or a string containing (as elements, or as substrings with any separator) the keyboard modifiers required.
-- @param key      A string containing the name of a keyboard key (as found in hs.keycodes.map ), or a raw keycode number.
-- @param bundleID Application Bundle Identifier
function toggleApp(mods, key, bundleID)
  hs.hotkey.bind(mods, key, function()
    local app = hs.application.get(bundleID)
    if app == nil then
      hs.application.launchOrFocusByBundleID(bundleID)
    elseif app:isFrontmost() then
      app:hide()
    else
      hs.application.launchOrFocusByBundleID(bundleID)
    end
  end)
end

-- ❯ lsappinfo info -only bundleid 'Alacritty'
-- "CFBundleIdentifier"="org.alacritty"
toggleApp({"cmd", "shift"}, "6", "org.alacritty")

-- ❯ lsappinfo info -only bundleid 'Obsidian'
-- "CFBundleIdentifier"="md.obsidian"
toggleApp({"cmd", "shift"}, "7", "md.obsidian")

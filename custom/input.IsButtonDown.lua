---Gets whether the specified button code is down.
---
--- Unlike [input.IsKeyDown](https://wiki.facepunch.com/gmod/input.IsKeyDown) this can also detect joystick presses from [Enums/JOYSTICK](https://wiki.facepunch.com/gmod/Enums/JOYSTICK).
---@realm client
---@realm menu
---@source https://wiki.facepunch.com/gmod/input.IsButtonDown
---@param button BUTTON_CODE|number The button, valid values are in the range of Enums/BUTTON_CODE.
---@return boolean # Is the button down?
function input.IsButtonDown(button) end

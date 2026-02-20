---Gets the button name from a numeric button code. The name needs to be translated with [language.GetPhrase](https://wiki.facepunch.com/gmod/language.GetPhrase) before being displayed.
---
--- **NOTE**: Despite the name of the function, this also works for the full range of keys in [Enums/BUTTON_CODE](https://wiki.facepunch.com/gmod/Enums/BUTTON_CODE).
---@realm client
---@realm menu
---@source https://wiki.facepunch.com/gmod/input.GetKeyName
---@param button BUTTON_CODE|number The button, see Enums/BUTTON_CODE.
---@return string # Button name.
function input.GetKeyName(button) end

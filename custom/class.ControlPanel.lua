--- Used by the context menu in sandbox.
---@class ControlPanel : DForm
local ControlPanel = {}

---Adds a [DLabel](https://wiki.facepunch.com/gmod/DLabel) to the ControlPanel as a helper text. Functionally equivalent to [DForm:Help](https://wiki.facepunch.com/gmod/DForm:Help).
---@realm client
---@param text string The text to display.
---@return DLabel # The created DLabel.
function ControlPanel:Label(text) end

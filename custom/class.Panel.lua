---@class Panel
---@field x number The x position of the panel relative to its parent.
---@field y number The y position of the panel relative to its parent.
Panel = Panel or {}

---Sets the value of this panel. This is a virtual method overridden by individual panel types (e.g. [DNumSlider](https://wiki.facepunch.com/gmod/DNumSlider), [DCheckBox](https://wiki.facepunch.com/gmod/DCheckBox), [DTextEntry](https://wiki.facepunch.com/gmod/DTextEntry)) to update the panel's displayed value. It is called automatically by [Panel:SetConVar](https://wiki.facepunch.com/gmod/Panel:SetConVar) when the convar changes.
---@realm client
---@realm menu
---@param value any The value to set. The type depends on the panel implementation.
function Panel:SetValue(value) end

---@class PANEL : Panel
PANEL = Panel

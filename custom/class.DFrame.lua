--- The DFrame is the moma of basically all VGUI elements. 98% of the time you will parent your element to this.
---@class DFrame : EditablePanel
---@field btnClose DButton The close button in the title bar.
---@field btnMaxim DButton The maximize button in the title bar (disabled by default).
---@field btnMinim DButton The minimize button in the title bar (disabled by default).
---@field lblTitle DLabel The title label in the title bar.
---@field imgIcon DImage|nil The icon image in the title bar, if set via DFrame:SetIcon.
local DFrame = {}

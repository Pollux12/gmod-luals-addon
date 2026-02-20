--- For a list of possible members of [Scripted Entities](https://wiki.facepunch.com/gmod/Scripted_Entities) see [ENT Structure](https://wiki.facepunch.com/gmod/Structures/ENT).
---@class Entity
---@field BaseClass table? The base class table of this entity, used for inheritance in the scripted entity system.
---@field EntityMods table? A table of entity modifications stored by the duplicator system via Entity:SetEntityMods.
local Entity = {}
---@class ENTITY : Entity
ENTITY = Entity

--- Table structure used for [util.TraceLine](https://wiki.facepunch.com/gmod/util.TraceLine).
---@realm shared
---@source https://wiki.facepunch.com/gmod/Structures/Trace
---@class Trace
local Trace = {}

---The start position of the trace
---@type Vector?
Trace.start = Vector(0, 0, 0)

---The end position of the trace
---@type Vector?
Trace.endpos = Vector(0, 0, 0)

---Things the trace should not hit. Can be an entity, a table of entities, a table of entity classes, a mixed table, or a function.
---
--- Using a function here is super slow. Try to avoid it.
---@type any
Trace.filter = nil

---The trace mask Enums/MASK. This determines what the trace should hit and what it shouldn't hit. A mask is a combination of Enums/CONTENTS - you can use these for more advanced masks.
---@type MASK?
Trace.mask = MASK_SOLID

---The collision group Enums/COLLISION_GROUP. This determines what the trace should hit in regards to the entity's collision group.
---@type COLLISION_GROUP?
Trace.collisiongroup = COLLISION_GROUP_NONE

---Should the trace ignore world or not
---@type boolean?
Trace.ignoreworld = false

---If set, the trace result will be written to the supplied table instead of returning a new table
---@type TraceResult|table|nil
Trace.output = nil

---Turns the `filter` field into a whitelist, if it is a table.
---@type boolean?
Trace.whitelist = false

---Enables traces to hit clientside only entities. Keep in mind that most naturally spawned entities are classified as debris, so extra `mask` values might be required.
---@type boolean?
Trace.hitclientonly = false

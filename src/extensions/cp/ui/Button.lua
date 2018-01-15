--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.ui.Button ===
---
--- Button Module.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log							= require("hs.logger").new("button")
local inspect						= require("hs.inspect")

local axutils						= require("cp.ui.axutils")
local prop							= require("cp.prop")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local Button = {}

-- TODO: Add documentation
function Button.matches(element)
	return element and element:attributeValue("AXRole") == "AXButton"
end

--- cp.ui.Button:new(axuielement, table) -> Button
--- Function
--- Creates a new Button
function Button:new(parent, finderFn)
	local o = {_parent = parent, _finder = finderFn}
	prop.extend(o, Button)

	-- TODO: Add documentation
	o.UI = prop(function(self)
		return self._finder()
	end):bind(o)

	o.showing = o.UI:mutate(function(ui, self)
		return ui ~= nil and self:parent():showing()
	end):bind(o):monitor(parent.showing)

	-- TODO: Add documentation
	o.enabled = o.UI:mutate(function(ui, self)
		return ui and ui:enabled()
	end):bind(o)

	return o
end

-- TODO: Add documentation
function Button:parent()
	return self._parent
end

-- TODO: Add documentation
function Button:press()
	local ui = self:UI()
	if ui then ui:doPress() end
	return self
end

return Button
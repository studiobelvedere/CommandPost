--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.ui.TextField ===
---
--- Text Field Module.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local axutils						= require("cp.ui.axutils")
local prop							= require("cp.prop")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local TextField = {}

-- TODO: Add documentation
function TextField.matches(element)
	return element:attributeValue("AXRole") == "AXTextField"
end

--- cp.ui.TextField:new(axuielement, function) -> TextField
--- Function
--- Creates a new TextField
function TextField:new(parent, finderFn)
	local o = {_parent = parent, _finder = finderFn}
	prop.extend(o, TextField)

-- TODO: Add documentation
	o.UI = prop(function(self)
		local ui = self._finder()
		return axutils.isValid(ui) and TextField.matches(ui) and ui or nil
	end):bind(o)

-- TODO: Add documentation
	o.showing = o.UI:mutate(function(ui, self)
		return ui ~= nil and self:parent():showing()
	end):bind(o):monitor(parent.showing)

	o.value = o.UI:mutate(
		function(ui, self)
			return ui and ui:attributeValue("AXValue")
		end,
		function(ui, value, self)
			if ui then
				ui:setAttributeValue("AXValue", value)
				ui:performAction("AXConfirm")
			end
		end
	):bind(o)

-- TODO: Add documentation
	o.enabled = o.UI:mutate(function(ui, self)
		return ui and ui:enabled()
	end):bind(o)
	o.isEnabled = o.enabled

	return o
end

-- TODO: Add documentation
function TextField:parent()
	return self._parent
end

-- TODO: Add documentation
function TextField:getValue()
	return self:value()
end

-- TODO: Add documentation
function TextField:setValue(value)
	self.value:set(value)
	return self
end

-- TODO: Add documentation
function TextField:clear()
	self.value:set("")
end

-- TODO: Add documentation
function TextField:saveLayout()
	local layout = {}
	layout.value = self:getValue()
	return layout
end

-- TODO: Add documentation
function TextField:loadLayout(layout)
	if layout then
		self:setValue(layout.value)
	end
end

return TextField
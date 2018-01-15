--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.ui.Slider ===
---
--- Slider Module.

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
local Slider = {}

-- TODO: Add documentation
function Slider.matches(element)
	return element:attributeValue("AXRole") == "AXSlider"
end

--- cp.ui.Slider:new(axuielement, function) -> Slider
--- Function
--- Creates a new Slider
function Slider:new(parent, finderFn)
	local o = {_parent = parent, _finder = finderFn}
	prop.extend(o, Slider)

	-- TODO: Add documentation
	o.UI = prop(function(self)
		local ui = self._finder()
		return axutils.isValid(ui) and Slider.matches(ui) and ui or nil
	end):bind(o)

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
			end
		end
	):bind(o)

	o.minValue = o.UI:mutate(function(ui, self)
		return ui and ui:attributeValue("AXMinValue")
	end):bind(o)

	o.maxValue = o.UI:mutate(function(ui, self)
		return ui and ui:attributeValue("AXMaxValue")
	end):bind(o)

-- TODO: Add documentation
	o.enabled = o.UI:mutate(function(ui, self)
		return ui and ui:enabled()
	end):bind(o)
	o.isEnabled = o.enabled

	return o
end

-- TODO: Add documentation
function Slider:parent()
	return self._parent
end


-- TODO: Add documentation
function Slider:getValue()
	return self:value()
end

-- TODO: Add documentation
function Slider:setValue(value)
	self.value:set(value)
	return self
end

-- TODO: Add documentation
function Slider:shiftValue(value)
	local currentValue = self:value()
	self.value:set(currentValue - value)
	return self
end

-- TODO: Add documentation
function Slider:getMinValue()
	return self:minValue()
end

-- TODO: Add documentation
function Slider:getMaxValue()
	return self:maxValue()
end

-- TODO: Add documentation
function Slider:increment()
	local ui = self:UI()
	if ui then
		ui:doIncrement()
	end
	return self
end

-- TODO: Add documentation
function Slider:decrement()
	local ui = self:UI()
	if ui then
		ui:doDecrement()
	end
	return self
end

-- TODO: Add documentation
function Slider:saveLayout()
	local layout = {}
	layout.value = self:getValue()
	return layout
end

-- TODO: Add documentation
function Slider:loadLayout(layout)
	if layout then
		self:setValue(layout.value)
	end
end

return Slider
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.ui.RadioButton ===
---
--- Radio Button Module.

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
local RadioButton = {}

-- TODO: Add documentation
function RadioButton.matches(element)
	return element:attributeValue("AXRole") == "AXRadioButton"
end

--- cp.ui.RadioButton:new(axuielement, function) -> RadioButton
--- Function
--- Creates a new RadioButton
function RadioButton:new(parent, finderFn)
	local o = {_parent = parent, _finder = finderFn}
	prop.extend(o, RadioButton)

-- TODO: Add documentation
	o.UI = prop(function(self)
		local ui = self._finder()
		return axutils.isValid(ui) and RadioButton.matches(ui) and ui or nil
	end):bind(o)

	o.showing = o.UI:mutate(function(ui, self)
		return ui ~= nil and self:parent():showing()
	end):bind(o):monitor(parent.showing)

-- TODO: Add documentation
	o.checked = o.UI:mutate(
		function(ui, self)
			return ui and ui:value() == 1
		end,
		function(ui, checked, self)
			local expected = checked and 1 or 0
			if ui and ui:value() ~= expected then
				ui:doPress()
			end
		end
	):bind(o)
	o.isChecked = o.checked


-- TODO: Add documentation
	o.enabled = o.UI:mutate(function(ui, self)
		return ui and ui:enabled()
	end):bind(o)

	return o
end

-- TODO: Add documentation
function RadioButton:parent()
	return self._parent
end

-- TODO: Add documentation
function RadioButton:check()
	self:checked(true)
	return self
end

-- TODO: Add documentation
function RadioButton:uncheck()
	self:checked(false)
	return self
end

-- TODO: Add documentation
function RadioButton:toggle()
	self.checked:toggle()
	return self
end

-- TODO: Add documentation
function RadioButton:press()
	local ui = self:UI()
	if ui then
		ui:doPress()
	end
	return self
end

-- TODO: Add documentation
function RadioButton:saveLayout()
	return {
		checked = self:isChecked()
	}
end

-- TODO: Add documentation
function RadioButton:loadLayout(layout)
	if layout then
		if layout.checked then
			self:check()
		else
			self:uncheck()
		end
	end
end

return RadioButton
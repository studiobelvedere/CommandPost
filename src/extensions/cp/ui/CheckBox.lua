--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.ui.CheckBox ===
---
--- Check Box UI Module.

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
local CheckBox = {}

-- TODO: Add documentation
function CheckBox.matches(element)
	return element:attributeValue("AXRole") == "AXCheckBox"
end

--- cp.ui.CheckBox:new(axuielement, function) -> CheckBox
--- Function
--- Creates a new CheckBox
function CheckBox:new(parent, finderFn)
	local o = {_parent = parent, _finder = finderFn}
	prop.extend(o, CheckBox)

--- cp.ui.CheckBox.UI <cp.prop: axuielement; read-only>
--- Field
--- The UI element for the checkbox.
	o.UI = prop(function(self)
		local ui = self._finder()
		return axutils.isValid(ui) and CheckBox.matches(ui) and ui
	end):bind(o):monitor(parent.UI)

--- cp.ui.CheckBox.showing <cp.prop: boolean; read-only>
--- Field
--- Returns `true` if the element is showing.
	o.showing = o.UI:mutate(function(ui, self)
		return ui ~= nil and self:parent():showing()
	end):bind(o)

--- cp.ui.CheckBox.checked <cp.prop: boolean>
--- Field
--- If `true`, the checkbox is checked.
	o.checked = o.UI:mutate(
		function(ui, self)
			return ui and ui:value() == 1
		end,
		function(ui, checked, self)
			local value = checked and 1 or 0
			if ui and ui:value() ~= value then
				ui:doPress()
			end
		end
	):bind(o)

--- cp.ui.CheckBox.enabled <cp.prop: boolean; read-only>
--- Field
--- If `true`, the checkbox is enabled.
	o.enabled = o.UI:mutate(
		function(ui, self)
			return ui and ui:enabled()
		end
	)

	return o
end

--- cp.ui.CheckBox:parent() -> table
--- Method
--- Returns the parent object.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The parent object.
function CheckBox:parent()
	return self._parent
end

-- TODO: Add documentation
function CheckBox:isChecked()
	return self:checked()
end

-- TODO: Add documentation
function CheckBox:check()
	self:checked(true)
	return self
end

-- TODO: Add documentation
function CheckBox:uncheck()
	self:checked(false)
	return self
end

-- TODO: Add documentation
function CheckBox:toggle()
	self.checked:toggle()
	return self
end

--- cp.ui.CheckBox:isEnabled()
--- Method
--- Checks if the checkbox is enabled.
---
--- Parameters:
--- * None
---
--- Returns:
--- * `true` if the checkbox is enabled.
function CheckBox:isEnabled()
	return self:enabled()
end

-- TODO: Add documentation
function CheckBox:press()
	local ui = self:UI()
	if ui then
		ui:doPress()
	end
	return self
end

-- TODO: Add documentation
function CheckBox:saveLayout()
	return {
		checked = self:isChecked()
	}
end

-- TODO: Add documentation
function CheckBox:loadLayout(layout)
	if layout then
		if layout.checked then
			self:check()
		else
			self:uncheck()
		end
	end
end

return CheckBox
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.ui.PopUpButton ===
---
--- Pop Up Button Module.

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
local PopUpButton = {}

-- TODO: Add documentation
function PopUpButton.matches(element)
	return element:attributeValue("AXRole") == "AXPopUpButton"
end

--- cp.ui.PopUpButton:new(axuielement, function) -> PopUpButton
--- Function
--- Creates a new PopUpButton
function PopUpButton:new(parent, finderFn)
	local o = {_parent = parent, _finder = finderFn}
	prop.extend(o, PopUpButton)

-- TODO: Add documentation
	o.UI = prop(function(self)
		local ui = self._finder()
		return axutils.isValid(ui) and PopUpButton.matches(ui) and ui or nil
	end):bind(o)

	o.showing = o.UI:mutate(function(ui, self)
		return ui ~= nil
	end):bind(o)

-- TODO: Add documentation
	o.enabled = o.UI:mutate(function(ui, self)
		return ui and ui:enabled()
	end):bind(o)
	o.isEnabled = o.enabled

	o.value = o.UI:mutate(
		function(ui, self)
			return ui and ui:value()
		end,
		function(ui, value, self)
			if ui and not ui:value() == value then
				local items = ui:doPress()[1]
				for i,item in items do
					if item:title() == value then
						item:doPress()
						return
					end
				end
				items:doCancel()
			end
			return self
		end
	):bind(o)

	return o
end

-- TODO: Add documentation
function PopUpButton:parent()
	return self._parent
end

-- TODO: Add documentation
function PopUpButton:selectItem(index)
	local ui = self:UI()
	if ui then
		local items = ui:doPress()[1]
		if items then
			local item = items[index]
			if item then
				-- select the menu item
				item:doPress()
			else
				-- close the menu again
				items:doCancel()
			end
		end
	end
	return self
end

-- TODO: Add documentation
function PopUpButton:getValue()
	return self:value()
end

-- TODO: Add documentation
function PopUpButton:setValue(value)
	return self.value:set(value)
end

-- TODO: Add documentation
function PopUpButton:press()
	local ui = self:UI()
	if ui then
		ui:doPress()
	end
	return self
end

-- TODO: Add documentation
function PopUpButton:saveLayout()
	local layout = {}
	layout.value = self:getValue()
	return layout
end

-- TODO: Add documentation
function PopUpButton:loadLayout(layout)
	if layout then
		self:setValue(layout.value)
	end
end

return PopUpButton

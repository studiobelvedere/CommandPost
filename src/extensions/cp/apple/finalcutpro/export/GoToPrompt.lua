--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.export.GoToPrompt ===
---
--- Go To Prompt.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log							= require("hs.logger").new("PrefsDlg")
local inspect						= require("hs.inspect")
local eventtap						= require("hs.eventtap")

local axutils						= require("cp.ui.axutils")
local just							= require("cp.just")
local prop							= require("cp.prop")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local GoToPrompt = {}

--- cp.apple.finalcutpro.export.GoToPrompt.matches(element) -> boolean
--- Function
--- Checks if the element matches the GoTo Prompt.
---
--- Parameters:
--- * element	- The `axuielement` to check
---
--- Returns:
--- * `true` if it matches.
function GoToPrompt.matches(element)
	if element then
		return element:attributeValue("AXRole") == "AXSheet"			-- it's a sheet
		   and (axutils.childWithRole(element, "AXTextField") ~= nil 	-- with a text field
		    or axutils.childWithRole(element, "AXComboBox") ~= nil)
	end
	return false
end

--- cp.apple.finalcutpro.export.GoToPrompt:new(parent) -> GoToPrompt
--- Method
--- Creates a new GoToPrompt instance.
---
--- Parameters:
--- * parent	- The parent object.
---
--- Returns:
--- * The new instance.
function GoToPrompt:new(parent)
	local o = {_parent = parent}
	prop.extend(o, GoToPrompt)

--- cp.apple.finalcutpro.export.GoToPrompt.UI <cp.prop: axuielement; read-only>
--- Field
--- The UI element for the Go To Prompt.
	o.UI = parent.UI:mutate(function(ui, self)
		return axutils.childMatching(ui, GoToPrompt.matches)
	end):bind(o)

--- cp.apple.finalcutpro.export.GoToPrompt.showing <cp.prop: boolean; read-only>
--- Field
--- Is the 'Go To' prompt showing?
	o.showing = o.UI:mutate(function(ui, self)
		return ui ~= nil
	end):bind(o)
	o.isShowing = o.showing

	return o
end

--- cp.apple.finalcutpro.export.GoToPrompt:parent() -> table
--- Method
--- Returns the parent instance.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The parent.
function GoToPrompt:parent()
	return self._parent
end

--- cp.apple.finalcutpro.export.GoToPrompt:app() -> table
--- Method
--- Returns the app instance.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The app.
function GoToPrompt:app()
	return self:parent():app()
end

--- cp.apple.finalcutpro.export.GoToPrompt:show() -> self
--- Method
--- Attempts to show the GoToPrompt window.
---
--- Parameters:
--- * None
---
--- Returns:
--- * `self`
function GoToPrompt:show()
	if self:parent():showing() then
		eventtap.keyStroke({"cmd", "shift"}, "g")
		just.doUntil(function() return self:showing() end)
	end
	return self
end

--- cp.apple.finalcutpro.export.GoToPrompt:hide() -> self
--- Method
--- Attempts to hide the prompt, if it is visible.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The GoToPrompt instance.
function GoToPrompt:hide()
	self:pressCancel()
	return self
end

--- cp.apple.finalcutpro.export.GoToPrompt:pressCancel() -> self
--- Method
--- Presses the Cancel button, if present.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The GoToPrompt instance.
function GoToPrompt:pressCancel()
	local ui = self:UI()
	if ui then
		local btn = ui:cancelButton()
		if btn then
			btn:doPress()
			just.doWhile(function() return self:showing() end)
		end
	end
	return self
end

--- cp.apple.finalcutpro.export.GoToPrompt:setValue(value) -> self
--- Method
--- Sets the value of the search field to the specified string value.
---
--- Parameters:
--- * value	- The text value to set.
---
--- Returns:
--- * The GoToPrompt instance.
function GoToPrompt:setValue(value)
	local textField = axutils.childWithRole(self:UI(), "AXTextField")
	if textField then
		textField:setAttributeValue("AXValue", value)
	else
		local comboBox = axutils.childWithRole(self:UI(), "AXComboBox")
		if comboBox then
			comboBox:setAttributeValue("AXValue", value)
		end
	end
	return self
end

--- cp.apple.finalcutpro.export.GoToPrompt:pressDefault() -> self
--- Method
--- Presses the Cancel button, if present.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The GoToPrompt instance.
function GoToPrompt:pressDefault()
	local ui = self:UI()
	if ui then
		local btn = ui:defaultButton()
		if btn and btn:enabled() then
			btn:doPress()
			just.doWhile(function() return self:showing() end)
		end
	end
	return self
end

--- cp.apple.finalcutpro.export.GoToPrompt:getTitle() -> string
--- Method
--- Returns the title of the dialog box.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The title, or `nil`
function GoToPrompt:getTitle()
	local ui = self:UI()
	return ui and ui:title()
end

return GoToPrompt
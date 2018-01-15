--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.cmd.CommandEditor ===
---
--- Command Editor Module.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log							= require("hs.logger").new("PrefsDlg")
local inspect						= require("hs.inspect")

local axutils						= require("cp.ui.axutils")
local just							= require("cp.just")

local Button						= require("cp.ui.Button")
local WindowWatcher					= require("cp.apple.finalcutpro.WindowWatcher")

local id							= require("cp.apple.finalcutpro.ids") "CommandEditor"
local prop							= require("cp.prop")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local CommandEditor = {}

-- TODO: Add documentation
function CommandEditor.matches(element)
	if element then
		return element:attributeValue("AXSubrole") == "AXDialog"
		   and element:attributeValue("AXModal")
		   and axutils.childWithRole(element, "AXPopUpButton") ~= nil
		   and #axutils.childrenWithRole(element, "AXGroup") == 4
	end
	return false
end

-- TODO: Add documentation
function CommandEditor:new(app)
	local o = {_app = app}
	prop.extend(o, CommandEditor)

--- cp.apple.finalcutpro.cmd.CommandEditor.UI <cp.prop: axuielement; read-only>
--- Field
--- The UI element for the Command Editor window.
	o.UI = app.windowsUI:mutate(function(windowsUI, self)
		return windowsUI and self._findWindowUI(windowsUI)
	end):bind(o)

--- cp.apple.finalcutpro.cmd.CommandEditor.showing <cp.prop: boolean; read-only>
--- Field
--- Is the Command Editor showing?
	o.showing = o.UI:mutate(function(ui, self)
		return ui ~= nil
	end):bind(o)
	o.isShowing = o.showing

	return o
end

--- cp.apple.finalcutpro.cmd.CommandEditor:app() -> table
--- Method
--- Returns the app.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The app.
function CommandEditor:app()
	return self._app
end

-- cp.apple.finalcut.cmd.CommandEditor._findWindowUI(windows) -> axuielement
-- Private Function
-- Finds the Command Editor window in the list of windows, or `nil` if not present.
--
-- Parameters:
-- * windows	- The list of windows
--
-- Returns:
-- * The window or `nil`.
function CommandEditor._findWindowUI(windows)
	for i,window in ipairs(windows) do
		if CommandEditor.matches(window) then return window end
	end
	return nil
end

--- cp.apple.finalcutpro.cmd.CommandEditor:show() -> self
--- Method
--- Ensures the CommandEditor is showing.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The CommandEditor instance.
function CommandEditor:show()
	if not self:showing() then
		-- open the window
		if self:app():menuBar():isEnabled({"Final Cut Pro", "Commands", "Customize…"}) then
			self:app():menuBar():selectMenu({"Final Cut Pro", "Commands", "Customize…"})
			local ui = just.doUntil(function() return self:UI() end)
		end
	end
	return self
end

--- cp.apple.finalcutpro.cmd.CommandEditor:hide() -> self
--- Method
--- Ensures the CommandEditor is hidden.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The CommandEditor instance.
function CommandEditor:hide()
	local ui = self:UI()
	if ui then
		local closeBtn = axutils.childWith(ui, "AXSubrole", "AXCloseButton")
		if closeBtn then
			closeBtn:doPress()
		end
	end
	return self
end

--- cp.apple.finalcutpro.cmd.CommandEditor:saveButton() -> cp.ui.Button
--- Method
--- Returns the Save `Button`.
---
--- Parameters:
--- * None
---
--- Returns:
--- The Save `Button`.
function CommandEditor:saveButton()
	if not self._saveButton then
		self._saveButton = Button:new(self, function()
			return axutils.childWithID(self:UI(), id "SaveButton")
		end)
	end
	return self._saveButton
end

--- cp.apple.finalcutpro.cmd.CommandEditor:save() -> self
--- Method
--- Saves the current command editor settings.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The CommandEditor instance.
function CommandEditor:save()
	local ui = self:UI()
	if ui then
		local saveBtn = axutils.childWith(ui, "AXIdentifier", id "SaveButton")
		if saveBtn and saveBtn:enabled() then
			saveBtn:doPress()
		end
	end
	return self
end

--- cp.apple.finalcutpro.cmd.CommandEditor:getTitle() -> string
--- Method
--- Retrieves the CommandEditor window title, if visible.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The title string, or `nil` if not open.
function CommandEditor:getTitle()
	local ui = self:UI()
	return ui and ui:title()
end

--- cp.apple.finalcutpro.cmd.CommandEditor:watch() -> bool
--- Method
--- Watch for events that happen in the command editor. The optional functions will be called when the window is shown or hidden, respectively.
---
--- Parameters:
---  * `events` - A table of functions with to watch. These may be:
---    * `open(window)` - Triggered when the window is shown.
---    * `close(window)` - Triggered when the window is hidden.
---    * `move(window)` - Triggered when the window is moved.
---
--- Returns:
---  * An ID which can be passed to `unwatch` to stop watching.
function CommandEditor:watch(events)
	if not self._watcher then
		self._watcher = WindowWatcher:new(self)
	end

	return self._watcher:watch(events)
end

--- cp.apple.finalcutpro.cmd.CommandEditor:unwatch(id)
--- Method
--- Unregisters the watcher with the specified ID.
---
--- Parameters:
--- * id	- The ID returned from the `watch` method when executed.
---
--- Returns:
--- * Nothing.
function CommandEditor:unwatch(id)
	if self._watcher then
		self._watcher:unwatch(id)
	end
end

return CommandEditor
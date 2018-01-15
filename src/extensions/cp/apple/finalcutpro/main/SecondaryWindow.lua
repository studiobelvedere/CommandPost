--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.main.SecondaryWindow ===
---
--- Secondary Window Module.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log							= require("hs.logger").new("secondaryWindow")
local inspect						= require("hs.inspect")

local axutils						= require("cp.ui.axutils")
local just							= require("cp.just")
local prop							= require("cp.prop")

local Button						= require("cp.ui.Button")
local Window						= require("cp.ui.Window")
local WindowWatcher					= require("cp.apple.finalcutpro.WindowWatcher")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local SecondaryWindow = {}

--- cp.apple.finalcutpro.main.SecondaryWindow.matches(element) -> boolean
--- Function
--- Checks if the provided `axuielement` matches the SecondaryWindow.
---
--- Parameters:
--- * element	- The element to check.
---
--- Returns:
--- * `true` if the element is the Secondary Window.
function SecondaryWindow.matches(element)
	if element and element:attributeValue("AXModal") == false then
		local children = element:attributeValue("AXChildren")
		return children and #children == 1 and children[1]:attributeValue("AXRole") == "AXSplitGroup"
	end
	return false
end

-- TODO: Add documentation
function SecondaryWindow:new(app)
	local o = {
		_app = app
	}
	prop.extend(o, SecondaryWindow)

	local window = Window:new(function()
		return axutils.childMatching(app:windowsUI(), SecondaryWindow.matches)
	end)
	o._window = window

	-- update whenever the application changes.
	window.UI:monitor(app.application)

--- cp.apple.finalcutpro.main.SecondaryWindow.UI <cp.prop: axuielement; read-only>
--- Field
--- The `axuielement` for the window.
	o.UI = window.UI:wrap(o)

--- cp.apple.finalcutpro.main.SecondaryWindow.showing <cp.prop: boolean>
--- Field
--- Is `true` if the window is visible.
	o.showing = window.visible:wrap(o)

--- cp.apple.finalcutpro.main.SecondaryWindow.fullScreen <cp.prop: boolean>
--- Field
--- Is `true` if the window is full-screen.
	o.fullScreen = window.fullScreen:wrap(o)

--- cp.apple.finalcutpro.main.SecondaryWindow.frame <cp.prop: frame>
--- Field
--- The current position (x, y, width, height) of the window.
	o.frame = window.frame:wrap(o)

--- cp.apple.finalcutpro.main.SecondaryWindow.window <cp.prop: hs.window; read-only>
--- Field
--- The `hs.window` object for the Secondary Window, if present.
	o.window = window.hsWindow:wrap(o)

--- cp.apple.finalcutpro.main.SecondaryWindow.rootGroupUI <cp.prop: axuielement; read-only>
--- Field
--- The root group UI element.
	o.rootGroupUI = o.UI:mutate(function(ui, self)
		return ui and axutils.childWithRole(ui, "AXSplitGroup")
	end):bind(o)

--- cp.apple.finalcutpro.main.SecondaryWindow.viewerGroupUI <cp.prop: axuielement; read-only>
--- Field
--- The viewer group UI element.
	o.viewerGroupUI = o.rootGroupUI

--- cp.apple.finalcutpro.main.SecondaryWindow.timelineGroupUI <cp.prop: axuielement; read-only>
--- Field
--- The timeline group UI.
	o.timelineGroupUI = o.rootGroupUI:mutate(function(root, self)
		-- for some reason, the Timeline is burried under three levels
		if root and root[1] and root[1][1] then
			return root[1][1]
		end
	end):bind(o)

--- cp.apple.finalcutpro.main.SecondaryWindow.browserGroupUI <cp.prop: axuielement; read-only>
--- Field
--- The browser group UI.
	o.browserGroupUI = o.rootGroupUI

	return o
end

--- cp.apple.finalcutpro.main.SecondaryWindow:app() -> app
--- Method
--- Provides the main app the window belongs to.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The app.
function SecondaryWindow:app()
	return self._app
end

--- cp.apple.finalcutpro.main.SecondaryWindow:show() -> boolean
--- Method
--- Shows the secondary window. Currently this does nothing.
---
--- Parameters:
--- * None
---
--- Returns:
--- * `true`
---
--- Notes:
--- * Currently, there is no way to activate the secondary window without specifying which thing to move there.
function SecondaryWindow:show()
	-- Currently a null-op. Determin if there are any scenarios where we need to force this.
	return true
end

-- cp.apple.finalcutpro.main.SecondaryWindow:_findWindowUI(windows)  -> axuielement
-- Method
-- Picks the Secondary Window from the table of windows, if present.
--
-- Parameters:
-- * windows	- The table of windows to check
--
-- Returns:
-- * The window, or `nil`.
function SecondaryWindow:_findWindowUI(windows)
	for i,w in ipairs(windows) do
		if SecondaryWindow.matches(w) then return w end
	end
	return nil
end

-----------------------------------------------------------------------
--
-- WATCHERS:
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.main.SecondaryWindow:watch() -> bool
--- Method
--- Watch for events that happen in the command editor
--- The optional functions will be called when the window
--- is shown or hidden, respectively.
---
--- Parameters:
---  * `events` - A table of functions with to watch. These may be:
---    * `show(window)` - Triggered when the window is shown.
---    * `hide(window)` - Triggered when the window is hidden.
---    * `move(window)` - Triggered when the window is moved.
---
--- Returns:
---  * An ID which can be passed to `unwatch` to stop watching.
function SecondaryWindow:watch(events)
	if not self._watcher then
		self._watcher = WindowWatcher:new(self)
	end

	return self._watcher:watch(events)
end

-- TODO: Add documentation
function SecondaryWindow:unwatch(id)
	if self._watcher then
		self._watcher:unwatch(id)
	end
end

return SecondaryWindow
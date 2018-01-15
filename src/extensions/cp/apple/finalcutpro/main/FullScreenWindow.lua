--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.main.FullScreenWindow ===
---
--- Full Screen Window

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local axutils						= require("cp.ui.axutils")
local just							= require("cp.just")
local prop							= require("cp.prop")
local WindowWatcher					= require("cp.apple.finalcutpro.WindowWatcher")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local FullScreenWindow = {}

-- TODO: Add documentation
function FullScreenWindow.matches(element)
	if element and element:attributeValue("AXSubrole") == "AXUnknown"
	and element:attributeValue("AXTitle") == "" then
		local children = element:attributeValue("AXChildren")
		return children and #children == 1 and children[1]:attributeValue("AXRole") == "AXSplitGroup"
	end
	return false
end

-- TODO: Add documentation
function FullScreenWindow:new(app)
	local o = {
		_app = app
	}
	prop.extend(o, FullScreenWindow)

-- TODO: Add documentation
	o.UI = app.UI:mutate(function(ui, self)
		if ui then
			if FullScreenWindow.matches(ui:attributeValue("AXMainWindow")) then
				return ui:mainWindow()
			else
				local windowsUI = self:app():windowsUI()
				return windowsUI and self._findWindowUI(windowsUI)
			end
		end
		return nil
	end):bind(o)

-- TODO: Add documentation
-- The top AXSplitGroup contains the
	o.rootGroupUI = o.UI:mutate(function(ui, self)
		return ui and axutils.childWithRole(ui, "AXSplitGroup")
	end):bind(o)

-- TODO: Add documentation
	o.viewerGroupUI = o.rootGroupUI:mutate(function(ui, self)
		if ui then
			local group = nil
			if #ui == 1 then
				group = ui[1]
			else
				group = axutils.childMatching(ui, function(element) return #element == 2 end)
			end
			if #group == 2 and axutils.childWithRole(group, "AXImage") ~= nil then
				return group
			end
		end
		return nil
	end):bind(o)

	o.showing = o.UI:mutate(function(ui, self)
		return ui ~= nil
	end):bind(o)
	o.isShowing = o.showing

-- TODO: Add documentation
	o.fullScreen = o.rootGroupUI:mutate(
		function(ui, self)
			if ui then
				-- In full-screen, it can either be a single group, or a sub-group containing the event viewer.
				local group = nil
				if #ui == 1 then
					group = ui[1]
				else
					group = axutils.childMatching(ui, function(element) return #element == 2 end)
				end
				if #group == 2 then
					local image = axutils.childWithRole(group, "AXImage")
					return image ~= nil
				end
			end
			return false
		end,
		function(ui, newValue, self)
			if ui then ui:setFullScreen(newValue) end
		end
	):bind(o)

	return o
end

-- TODO: Add documentation
function FullScreenWindow:app()
	return self._app
end

-- TODO: Add documentation
function FullScreenWindow:show()
	-- Currently a null-op. Determin if there are any scenarios where we need to force this.
	return true
end

-- TODO: Add documentation
function FullScreenWindow._findWindowUI(windows)
	for i,w in ipairs(windows) do
		if FullScreenWindow.matches(w) then return w end
	end
	return nil
end

-----------------------------------------------------------------------
--
-- WATCHERS:
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.main.FullScreenWindow:watch() -> bool
--- Method
--- Watch for events that happen in the command editor
--- The optional functions will be called when the window
--- is shown or hidden, respectively.
---
--- Parameters:
---  * `events` - A table of functions with to watch. These may be:
---    * `show(CommandEditor)` - Triggered when the window is shown.
---    * `hide(CommandEditor)` - Triggered when the window is hidden.
---
--- Returns:
---  * An ID which can be passed to `unwatch` to stop watching.
function FullScreenWindow:watch(events)
	if not self._watcher then
		self._watcher = WindowWatcher:new(self)
	end

	self._watcher:watch(events)
end

-- TODO: Add documentation
function FullScreenWindow:unwatch(id)
	if self._watcher then
		self._watcher:unwatch(id)
	end
end

return FullScreenWindow

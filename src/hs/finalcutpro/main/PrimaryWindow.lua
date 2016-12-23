local log							= require("hs.logger").new("PrefsDlg")
local inspect						= require("hs.inspect")

local axutils						= require("hs.finalcutpro.axutils")
local just							= require("hs.just")

local Button						= require("hs.finalcutpro.ui.Button")

local Browser						= require("hs.finalcutpro.main.Browser")
local Inspector						= require("hs.finalcutpro.main.Inspector")
local ColorBoard					= require("hs.finalcutpro.main.ColorBoard")
local Viewer						= require("hs.finalcutpro.main.Viewer")
local Timeline						= require("hs.finalcutpro.main.Timeline")

local PrimaryWindow = {}

function PrimaryWindow.isPrimaryWindow(w)
	return w and w:attributeValue("AXSubrole") == "AXStandardWindow"
end


function PrimaryWindow:new(app)
	o = {
		_app = app
	}
	setmetatable(o, self)
	self.__index = self
	
	return o
end

function PrimaryWindow:app()
	return self._app
end

function PrimaryWindow:show()
	-- Currently a null-op. Determin if there are any scenarios where we need to force this.
	return true
end

function PrimaryWindow:UI()
	return axutils.cache(self, "_ui", function()
		local ui = self:app():UI():mainWindow()
		if not PrimaryWindow.isPrimaryWindow(ui) then
			local windowsUI = self:app():windowsUI()
			ui = windowsUI and self:_findWindowUI(windowsUI)
		end
		return ui
	end)
end

function PrimaryWindow:_findWindowUI(windows)
	for i,w in ipairs(windows) do
		if PrimaryWindow.isPrimaryWindow(w) then return w end
	end
	return nil
end

function PrimaryWindow:isFullScreen()
	local ui = self:UI()
	return ui and ui:fullScreen()
end

function PrimaryWindow:setFullScreen(isFullScreen)
	local ui = self:UI()
	if ui then ui:setFullScreen(isFullScreen) end
	return self
end

function PrimaryWindow:toggleFullScreen()
	local ui = self:UI()
	if ui then ui:setFullScreen(not self:isFullScreen()) end
	return self
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- UI STRUCTURE
-----------------------------------------------------------------------
-----------------------------------------------------------------------

-- The top AXSplitGroup contains the 
function PrimaryWindow:rootGroupUI()
	return axutils.cache(self, "_rootGroup", function()
		local ui = self:UI()
		return ui and axutils.childWith(ui, "AXRole", "AXSplitGroup")
	end)
end

function PrimaryWindow:leftGroupUI()
	return axutils.cache(self, "_leftGroup", function()
		local root = self:rootGroupUI()
		if root then
			for i,child in ipairs(root) do
				-- the left group has only one child
				if #child == 1 then
					return child[1]
				end
			end
		end
		return nil
	end)
end

function PrimaryWindow:rightGroupUI()
	return axutils.cache(self, "_rightGroup", function()
		local root = self:rootGroupUI()
		if root and #root == 2 then
			if #(root[1]) >= 3 then
				return root[1]
			else
				return root[2]
			end
		end
		return nil
	end)
end

function PrimaryWindow:topGroupUI()
	return axutils.cache(self, "_topGroup", function()
		local left = self:leftGroupUI()
		if left and #left >= 3 then
			for i,child in ipairs(left) do
				if #child == 1 and #(child[1]) > 1 then
					return child[1]
				end
			end
		end
		return nil	
	end)
end

function PrimaryWindow:bottomGroupUI()
	return axutils.cache(self, "_bottomGroup", function()
		local left = self:leftGroupUI()
		if left and #left >= 3 then
			for i,child in ipairs(left) do
				if #child == 1 and #(child[1]) == 1 then
					return child[1]
				end
			end
		end
		return nil	
	end)
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- INSPECTOR
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function PrimaryWindow:inspector()
	if not self._inspector then
		self._inspector = Inspector:new(self)
	end
	return self._inspector
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- INSPECTOR
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function PrimaryWindow:colorBoard()
	if not self._colorBoard then
		self._colorBoard = ColorBoard:new(self)
	end
	return self._colorBoard
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- VIEWER
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function PrimaryWindow:viewerGroupUI()
	return self:topGroupUI()
end

function PrimaryWindow:viewer()
	if not self._viewer then
		self._viewer = Viewer:new(self, false, false)
	end
	return self._viewer
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- EVENT VIEWER
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function PrimaryWindow:eventViewer()
	if not self._eventViewer then
		self._eventViewer = Viewer:new(self, true, false)
	end
	return self._eventViewer
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
--- TIMELINE UI
-----------------------------------------------------------------------
-----------------------------------------------------------------------

function PrimaryWindow:timelineGroupUI()
	return self:bottomGroupUI()
end

function PrimaryWindow:timeline()
	if not self._timeline then
		self._timeline = Timeline:new(self)
	end
	return self._timeline
end

-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- BROWSER
-----------------------------------------------------------------------
-----------------------------------------------------------------------
function PrimaryWindow:browserGroupUI()
	return self:topGroupUI()
end

function PrimaryWindow:browser()
	if not self._browser then
		self._browser = Browser:new(self)
	end
	return self._browser
end

return PrimaryWindow
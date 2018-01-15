--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.main.MediaBrowser ===
---
--- Media Browser Module.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log								= require("hs.logger").new("mediaBrowser")
local inspect							= require("hs.inspect")

local just								= require("cp.just")
local prop								= require("cp.prop")
local axutils							= require("cp.ui.axutils")

local PrimaryWindow						= require("cp.apple.finalcutpro.main.PrimaryWindow")
local SecondaryWindow					= require("cp.apple.finalcutpro.main.SecondaryWindow")
local Button							= require("cp.ui.Button")
local Table								= require("cp.ui.Table")
local ScrollArea						= require("cp.ui.ScrollArea")
local CheckBox							= require("cp.ui.CheckBox")
local PopUpButton						= require("cp.ui.PopUpButton")
local TextField							= require("cp.ui.TextField")

local id								= require("cp.apple.finalcutpro.ids") "MediaBrowser"

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local MediaBrowser = {}

MediaBrowser.TITLE = "Photos and Audio"

MediaBrowser.MAX_SECTIONS = 4
MediaBrowser.PHOTOS = 1
MediaBrowser.GARAGE_BAND = 2
MediaBrowser.ITUNES = 3
MediaBrowser.SOUND_EFFECTS = 4

-- TODO: Add documentation
function MediaBrowser:new(parent)
	local o = {_parent = parent}
	prop.extend(o, MediaBrowser)

--- cp.apple.finalcutpro.main.MediaBrowser.UI <cp.prop: axuielement; read-only>
--- Field
--- The UI element for the Media Browser, or `nil`.
	o.UI = parent.UI:mutate(function(ui, self)
		return self:showing() and ui or nil
	end):bind(o)


--- cp.apple.finalcutpro.main.MediaBrowser.mainGroupUI <cp.prop: axuielement; read-only>
--- Field
--- The UI element for the main group in the browser.
	o.mainGroupUI = o.UI:mutate(function(ui, self)
		return axutils.isValid(ui) and axutils.childWithRole(ui, "AXSplitGroup")
	end):bind(o)

--- cp.apple.finalcutpro.main.MediaBrowser.showing <cp.prop: boolean; read-only>
--- Field
--- If `true`, the browser is showing.
	o.showing = parent.showing:AND(parent:showMedia().checked):bind(o)

	return o
end

-- TODO: Add documentation
function MediaBrowser:parent()
	return self._parent
end

-- TODO: Add documentation
function MediaBrowser:app()
	return self:parent():app()
end

-----------------------------------------------------------------------
--
-- MEDIABROWSER UI:
--
-----------------------------------------------------------------------

-- TODO: Add documentation
function MediaBrowser:show()
	local menuBar = self:app():menuBar()
	-- Go there direct
	menuBar:selectMenu({"Window", "Go To", MediaBrowser.TITLE})
	just.doUntil(function() return self:showing() end)
	return self
end

-- TODO: Add documentation
function MediaBrowser:hide()
	self:parent():hide()
	return self
end

-----------------------------------------------------------------------------
--
-- SECTIONS:
--
-----------------------------------------------------------------------------

-- TODO: Add documentation
function MediaBrowser:sidebar()
	if not self._sidebar then
		self._sidebar = Table.new(self, function()
			return axutils.childWithID(self:mainGroupUI(), id "Sidebar")
		end):uncached()
	end
	return self._sidebar
end

-- TODO: Add documentation
function MediaBrowser:group()
	if not self._group then
		self._group = PopUpButton:new(self, function()
			return axutils.childWithRole(self:UI(), "AXPopUpButton")
		end)
	end
	return self._group
end

-- TODO: Add documentation
function MediaBrowser:search()
	if not self._search then
		self._search = TextField:new(self, function()
			return axutils.childWithRole(self:mainGroupUI(), "AXTextField")
		end)
	end
	return self._search
end

-- TODO: Add documentation
function MediaBrowser:showSidebar()
	self:app():menuBar():checkMenu({"Window", "Show in Workspace", "Sidebar"})
end

-- TODO: Add documentation
function MediaBrowser:topCategoriesUI()
	return self:sidebar():rowsUI(function(row)
		return row:attributeValue("AXDisclosureLevel") == 0
	end)
end

-- TODO: Add documentation
function MediaBrowser:showSection(index)
	self:showSidebar()
	local topCategories = self:topCategoriesUI()
	if topCategories and #topCategories == MediaBrowser.MAX_SECTIONS then
		self:sidebar():selectRow(topCategories[index])
	end
	return self
end

-- TODO: Add documentation
function MediaBrowser:showPhotos()
	return self:showSection(MediaBrowser.PHOTOS)
end

-- TODO: Add documentation
function MediaBrowser:showGarageBand()
	return self:showSection(MediaBrowser.GARAGE_BAND)
end

-- TODO: Add documentation
function MediaBrowser:showITunes()
	return self:showSection(MediaBrowser.ITUNES)
end

-- TODO: Add documentation
function MediaBrowser:showSoundEffects()
	return self:showSection(MediaBrowser.SOUND_EFFECTS)
end

-- TODO: Add documentation
function MediaBrowser:saveLayout()
	local layout = {}
	if self:showing() then
		layout.showing = true
		layout.sidebar = self:sidebar():saveLayout()
		layout.search = self:search():saveLayout()
	end
	return layout
end

-- TODO: Add documentation
function MediaBrowser:loadLayout(layout)
	if layout and layout.showing then
		self:show()
		self:sidebar():loadLayout(layout.sidebar)
		self:search():loadLayout(layout.sidebar)
	end
end

return MediaBrowser
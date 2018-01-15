--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.main.Browser ===
---
--- Browser Module.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log								= require("hs.logger").new("browser")
local inspect							= require("hs.inspect")

local just								= require("cp.just")
local prop								= require("cp.prop")
local axutils							= require("cp.ui.axutils")

local PrimaryWindow						= require("cp.apple.finalcutpro.main.PrimaryWindow")
local SecondaryWindow					= require("cp.apple.finalcutpro.main.SecondaryWindow")
local LibrariesBrowser					= require("cp.apple.finalcutpro.main.LibrariesBrowser")
local MediaBrowser						= require("cp.apple.finalcutpro.main.MediaBrowser")
local GeneratorsBrowser					= require("cp.apple.finalcutpro.main.GeneratorsBrowser")
local CheckBox							= require("cp.ui.CheckBox")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local Browser = {}

--- cp.apple.finalcutpro.main.Browser.matches(element) -> boolean
--- Function
--- Checks if the element provided is the Browser.
---
--- Parameters:
--- * element	- The element to check
---
--- Returns:
--- * `true` if the element matches.
function Browser.matches(element)
	local checkBoxes = axutils.childrenWithRole(element, "AXCheckBox")
	return checkBoxes and #checkBoxes >= 3
end

--- cp.apple.finalcutpro.main.Browser:new(app) -> Browser
--- Method
--- Creates a new instance of a `Browser`, linked to the specified App instance.
---
--- Parameters:
--- * app	- The app to link to.
---
--- Returns:
--- * New instance of `Browser`.
function Browser:new(app)
	local o = {_app = app}
	prop.extend(o, Browser)

--- cp.apple.finalcutpro.main.Browser.UI <cp.prop: axuielement; read-only>
--- Field
--- The main UI element for the Browser.
	o.UI = prop(function(self)
		local app = self:app()
		return Browser._findBrowser(app:secondaryWindow(), app:primaryWindow())
	end):bind(o)
	:monitor(app:primaryWindow().UI)
	:monitor(app:secondaryWindow().UI)

--- cp.apple.finalcutpro.main.Browser.showing <cp.prop: boolean; read-only>
--- Field
--- Is the Browser showing?
	o.showing = o.UI:mutate(function(ui, self)
		return ui ~= nil
	end):bind(o)
	o.isShowing = o.showing

--- cp.apple.finalcutpro.main.Browser.onSecondary <cp.prop: boolean; read-only>
--- Field
--- Is the Browser on the Secondary Window?
	o.onSecondary = o.UI:mutate(function(ui, self)
		return ui and SecondaryWindow.matches(ui:window())
	end):bind(o)
	o.isOnSecondary = o.onSecondary

--- cp.apple.finalcutpro.main.Browser <cp.prop: boolean; read-only>
--- Field
--- Is the Browser on the Primary Window?
	o.onPrimary = o.UI:mutate(function(ui, self)
		return ui and PrimaryWindow.matches(ui:window())
	end):bind(o)
	o.isOnPrimary = o.onPrimary

	return o
end

-- TODO: Add documentation
function Browser:app()
	return self._app
end

-----------------------------------------------------------------------
--
-- BROWSER UI:
--
-----------------------------------------------------------------------

-- TODO: Add documentation
function Browser._findBrowser(...)
	for i = 1,select("#", ...) do
		local window = select(i, ...)
		if window then
			local ui = window:browserGroupUI()
			if ui then
				local browser = axutils.childMatching(ui, Browser.matches)
				if axutils.isValid(browser) then return browser end
			end
		end
	end
	return nil
end

-- TODO: Add documentation
function Browser:showOnPrimary()
	-- show the parent.
	local menuBar = self:app():menuBar()

	-- if the browser is on the secondary, we need to turn it off before enabling in primary
	if self:isOnSecondary() then
		menuBar:checkMenu({"Window", "Show in Secondary Display", "Browser"})
	end
	-- Then enable it in the primary
	if not self:showing() then
		menuBar:checkMenu({"Window", "Show in Workspace", "Browser"})
	end
	return self
end

-- TODO: Add documentation
function Browser:showOnSecondary()
	-- show the parent.
	local menuBar = self:app():menuBar()

	if not self:isOnSecondary() then
		menuBar:selectMenu({"Window", "Show in Secondary Display", "Browser"})
	end
	return self
end

-- TODO: Add documentation
function Browser:hide()
	if self:showing() then
		-- Uncheck it from the workspace
		self:app():menuBar():selectMenu({"Window", "Show in Workspace", "Browser"})
	end
	return self
end

-----------------------------------------------------------------------
--
-- SECTIONS:
--
-----------------------------------------------------------------------

-- TODO: Add documentation
function Browser:showLibraries()
	if not self._showLibraries then
		self._showLibraries = CheckBox:new(self, function()
			local ui = self:UI()
			if ui and #ui > 3 then
				-- The library toggle is always the last element.
				return ui[#ui]
			end
			return nil
		end)
	end
	return self._showLibraries
end

-- TODO: Add documentation
function Browser:showMedia()
	if not self._showMedia then
		self._showMedia = CheckBox:new(self, function()
			local ui = self:UI()
			if ui and #ui > 3 then
				-- The media toggle is always the second-last element.
				return ui[#ui-1]
			end
			return nil
		end)
	end
	return self._showMedia
end

-- TODO: Add documentation
function Browser:showGenerators()
	if not self._showGenerators then
		self._showGenerators = CheckBox:new(self, function()
			local ui = self:UI()
			if ui and #ui > 3 then
				-- The generators toggle is always the third-last element.
				return ui[#ui-2]
			end
			return nil
		end)
	end
	return self._showGenerators
end

-- TODO: Add documentation
function Browser:libraries()
	if not self._libraries then
		self._libraries = LibrariesBrowser:new(self)
	end
	return self._libraries
end

-- TODO: Add documentation
function Browser:media()
	if not self._media then
		self._media = MediaBrowser:new(self)
	end
	return self._media
end

-- TODO: Add documentation
function Browser:generators()
	if not self._generators then
		self._generators = GeneratorsBrowser:new(self)
	end
	return self._generators
end

-- TODO: Add documentation
function Browser:saveLayout()
	local layout = {}
	if self:showing() then
		layout.showing = true
		layout.onPrimary = self:isOnPrimary()
		layout.onSecondary = self:isOnSecondary()

		layout.showLibraries = self:showLibraries():saveLayout()
		layout.showMedia = self:showMedia():saveLayout()
		layout.showGenerators = self:showGenerators():saveLayout()

		layout.libraries = self:libraries():saveLayout()
		layout.media = self:media():saveLayout()
		layout.generators = self:generators():saveLayout()
	end
	return layout
end

-- TODO: Add documentation
function Browser:loadLayout(layout)
	if layout and layout.showing then
		if layout.onPrimary then self:showOnPrimary() end
		if layout.onSecondary then self:showOnSecondary() end

		self:generators():loadLayout(layout.generators)
		self:media():loadLayout(layout.media)
		self:libraries():loadLayout(layout.libraries)

		self:showGenerators():loadLayout(layout.showGenerators)
		self:showMedia():loadLayout(layout.showMedia)
		self:showLibraries():loadLayout(layout.showLibraries)
	end
end

return Browser
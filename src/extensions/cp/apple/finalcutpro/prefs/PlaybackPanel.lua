--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.prefs.PlaybackPanel ===
---
--- Playback Panel Module.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log								= require("hs.logger").new("playbackPanel")
local inspect							= require("hs.inspect")

local axutils							= require("cp.ui.axutils")
local just								= require("cp.just")
local prop								= require("cp.prop")
local CheckBox							= require("cp.ui.CheckBox")

local id								= require("cp.apple.finalcutpro.ids") "PlaybackPanel"

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local PlaybackPanel = {}

-- TODO: Add documentation
function PlaybackPanel:new(preferencesDialog)
	local parent = preferencesDialog
	local o = {_parent = parent}
	prop.extend(o, PlaybackPanel)

-- TODO: Add documentation
	o.UI = parent.toolbarUI:mutate(function(ui, self)
		return axutils.childFromLeft(ui, id "ID")
	end):bind(o)

-- TODO: Add documentation
	o.showing = parent.toolbarUI:mutate(function(toolbar, self)
		if toolbar then
			local selected = toolbar:selectedChildren()
			return #selected == 1 and selected[1] == self:UI()
		end
		return false
	end):bind(o)

	o.contentsUI = parent.groupUI:mutate(function(ui, self)
		return o.showing() and ui or nil
	end):bind(o):monitor(o.showing)

	return o
end

-- TODO: Add documentation
function PlaybackPanel:parent()
	return self._parent
end

-- TODO: Add documentation
function PlaybackPanel:show()
	local parent = self:parent()
	-- show the parent.
	if parent:show():showing() then
		-- get the toolbar UI
		local panel = just.doUntil(function() return self:UI() end)
		if panel then
			panel:doPress()
			just.doUntil(function() return self:showing() end)
		end
	end
	return self
end

function PlaybackPanel:hide()
	self:parent():hide()
	return self
end

function PlaybackPanel:createMulticamOptimizedMedia()
	if not self._createOptimizedMedia then
		self._createOptimizedMedia = CheckBox:new(self, function()
			return axutils.childFromTop(axutils.childrenWithRole(self:contentsUI(), "AXCheckBox"), id "CreateMulticamOptimizedMedia")
		end)
	end
	return self._createOptimizedMedia
end

function PlaybackPanel:backgroundRender()
	if not self._backgroundRender then
		self._backgroundRender = CheckBox:new(self, function()
			return axutils.childFromTop(axutils.childrenWithRole(self:contentsUI(), "AXCheckBox"), id "BackgroundRender")
		end)
	end
	return self._backgroundRender
end

return PlaybackPanel
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.prefs.ImportPanel ===
---
--- Import Panel Module.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log								= require("hs.logger").new("importPanel")
local inspect							= require("hs.inspect")

local just								= require("cp.just")
local prop								= require("cp.prop")
local axutils							= require("cp.ui.axutils")
local CheckBox							= require("cp.ui.CheckBox")
local RadioButton						= require("cp.ui.RadioButton")

local id								= require("cp.apple.finalcutpro.ids") "ImportPanel"

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local ImportPanel = {}

-- TODO: Add documentation
function ImportPanel:new(preferencesDialog)
	local parent = preferencesDialog
	local o = {_parent = parent}
	prop.extend(o, ImportPanel)

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
		return o.showing() and ui
	end):bind(o):monitor(o.showing)

	o.mediaLocationGroupUI = o.contentsUI:mutate(function(ui, self)
		return axutils.childFromTop(axutils.childrenWithRole(ui, "AXRadioGroup"), id "MediaLocationGroup")
	end):bind(o)

	return o
end

-- TODO: Add documentation
function ImportPanel:parent()
	return self._parent
end

-- TODO: Add documentation
function ImportPanel:show()
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

function ImportPanel:hide()
	return self:parent():hide()
end

function ImportPanel:createProxyMedia()
	if not self._createProxyMedia then
		self._createProxyMedia = CheckBox:new(self, function()
			return axutils.childFromTop(axutils.childrenWithRole(self:contentsUI(), "AXCheckBox"), id "CreateProxyMedia")
		end)
	end
	return self._createProxyMedia
end

function ImportPanel:createOptimizedMedia()
	if not self._createOptimizedMedia then
		self._createOptimizedMedia = CheckBox:new(self, function()
			return axutils.childFromTop(axutils.childrenWithRole(self:contentsUI(), "AXCheckBox"), id "CreateOptimizedMedia")
		end)
	end
	return self._createOptimizedMedia
end

function ImportPanel:copyToMediaFolder()
	if not self._copyToMediaFolder then
		self._copyToMediaFolder = RadioButton:new(self, function()
			local groupUI = self:mediaLocationGroupUI()
			return groupUI and groupUI[id "CopyToMediaFolder"]
		end)
	end
	return self._copyToMediaFolder
end

function ImportPanel:leaveInPlace()
	if not self._leaveInPlace then
		self._leaveInPlace = RadioButton:new(self, function()
			local groupUI = self:mediaLocationGroupUI()
			return groupUI and groupUI[id "LeaveInPlace"]
		end)
	end
	return self._leaveInPlace
end

-- TODO: Add documentation
function ImportPanel:toggleMediaLocation()
	if self:show():showing() then
		if self:copyToMediaFolder():isChecked() then
			self:leaveInPlace():check()
		else
			self:copyToMediaFolder():check()
		end
		return true
	end
	return false
end

return ImportPanel
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.main.TimelineToolbar ===
---
--- Timeline Toolbar

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local axutils							= require("cp.ui.axutils")
local prop								= require("cp.prop")

local CheckBox							= require("cp.ui.CheckBox")
local RadioButton						= require("cp.ui.RadioButton")

local TimelineAppearance				= require("cp.apple.finalcutpro.main.TimelineAppearance")

local id								= require("cp.apple.finalcutpro.ids") "TimelineToolbar"

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local TimelineToolbar = {}

-- TODO: Add documentation
function TimelineToolbar.matches(element)
	return element and element:attributeValue("AXIdentifier") ~= id "ID"
end

-- TODO: Add documentation
function TimelineToolbar:new(parent)
	local o = {_parent = parent}
	prop.extend(o, TimelineToolbar)

-- TODO: Add documentation
	o.UI = parent.UI:mutate(function(ui, self)
		return axutils.childMatching(ui, TimelineToolbar.matches)
	end):bind(o)

-- TODO: Add documentation
	o.showing = o.UI:mutate(function(ui, self)
		return ui ~= nil
	end):bind(o)

-- TODO: Add documentation
-- Contains buttons relating to mouse skimming behaviour:
	o.skimmingGroupUI = o.UI:mutate(function(ui, self)
		return axutils.childWithID(ui, id "SkimmingGroup")
	end):bind(o)

-- TODO: Add documentation
	o.effectsGroupUI = o.UI:mutate(function(ui, self)
		return axutils.childWithID(ui, id "EffectsGroup")
	end):bind(o)

	return o
end

-- TODO: Add documentation
function TimelineToolbar:parent()
	return self._parent
end

-- TODO: Add documentation
function TimelineToolbar:app()
	return self:parent():app()
end


-----------------------------------------------------------------------
--
-- THE BUTTONS:
--
-----------------------------------------------------------------------

-- TODO: Add documentation
function TimelineToolbar:appearance()
	if not self._appearance then
		self._appearance = TimelineAppearance:new(self)
	end
	return self._appearance
end

-- TODO: Add documentation
function TimelineToolbar:effectsToggle()
	if not self._effectsToggle then
		self._effectsToggle = RadioButton:new(self, function()
			local effectsGroup = self:effectsGroupUI()
			return effectsGroup and effectsGroup[1]
		end)
	end
	return self._effectsToggle
end

-- TODO: Add documentation
function TimelineToolbar:transitionsToggle()
	if not self._transitionsToggle then
		self._transitionsToggle = RadioButton:new(self, function()
			local effectsGroup = self:effectsGroupUI()
			return effectsGroup and effectsGroup[2]
		end)
	end
	return self._transitionsToggle
end

return TimelineToolbar
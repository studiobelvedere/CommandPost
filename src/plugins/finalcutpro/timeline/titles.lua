--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   C  O  M  M  A  N  D  P  O  S  T                          --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === plugins.finalcutpro.timeline.titles ===
---
--- Controls Final Cut Pro's Titles.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log				= require("hs.logger").new("titles")

local chooser			= require("hs.chooser")
local drawing			= require("hs.drawing")
local screen			= require("hs.screen")
local timer				= require("hs.timer")

local choices			= require("cp.choices")
local config			= require("cp.config")
local dialog			= require("cp.dialog")
local fcp				= require("cp.apple.finalcutpro")
local tools				= require("cp.tools")
local prop				= require("cp.prop")

--------------------------------------------------------------------------------
--
-- CONSTANTS:
--
--------------------------------------------------------------------------------
local PRIORITY 			= 3000
local MAX_SHORTCUTS 	= 5

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

local action = {}

function action.init(actionmanager)
	action._manager = actionmanager
	action._manager.addAction(action)

	fcp.currentLanguage:watch(function(value)
		action.reset()
		timer.doAfter(0.01, function() action.choices:update() end)
	end)
end

function action.id()
	return "title"
end

action.enabled = config.prop(action.id().."ActionEnabled", true)

action.choices = prop(function()
	if not action._choices then
		action._choices = choices.new(action.id())

		-- get the titles in the current language.
		local list = fcp:plugins():titles()
		if list then
			for i,plugin in ipairs(list) do
				local params = { name = plugin.name, category = plugin.category }
				local subText = i18n("title_group")
				if plugin.category then
					subText = subText..": "..plugin.category
				end
				if plugin.theme then
					subText = subText.." ("..plugin.theme..")"
				end
				action._choices:add(plugin.name)
					:subText(subText)
					:params(params)
					:id(action.getId(params))
			end
		end
	end
	return action._choices
end)

function action.getId(params)
	return string.format("%s:%s:%s", action.id(), params.category, params.name)
end

function action.execute(params)
	if action.enabled() and params and params.name then
		mod.apply(params.name, params.category)
		return true
	end
	return false
end

function action.reset()
	action._choices = nil
end

function mod.getShortcuts()
	return config.get(fcp:currentLanguage() .. ".titlesShortcuts", {})
end

function mod.getShortcut(number)
	local shortcuts = mod.getShortcuts()
	return shortcuts and shortcuts[number]
end

function mod.setShortcut(number, value)
	assert(number >= 1 and number <= MAX_SHORTCUTS)
	local shortcuts = mod.getShortcuts()
	shortcuts[number] = value
	config.set(fcp:currentLanguage() .. ".titlesShortcuts", shortcuts)
end

--------------------------------------------------------------------------------
-- TITLES SHORTCUT PRESSED:
-- The shortcut may be a number from 1-5, in which case the 'assigned' shortcut is applied,
-- or it may be the name of the title to apply in the current FCPX language.
--------------------------------------------------------------------------------
function mod.apply(shortcut, category)

	--------------------------------------------------------------------------------
	-- Get settings:
	--------------------------------------------------------------------------------
	if type(shortcut) == "number" then
		local params = mod.getShortcut(shortcut)
		if type(params) == "table" then
			shortcut = params.name
			category = params.category
		else
			shortcut = tostring(params)
		end
	end

	if shortcut == nil then
		dialog.displayMessage(i18n("noTitleShortcut"))
		return false
	end

	--------------------------------------------------------------------------------
	-- Save the main Browser layout:
	--------------------------------------------------------------------------------
	local browser = fcp:browser()
	local browserLayout = browser:saveLayout()

	--------------------------------------------------------------------------------
	-- Get Titles Browser:
	--------------------------------------------------------------------------------
	local generators = fcp:generators()
	local generatorsShowing = generators:isShowing()
	local generatorsLayout = generators:saveLayout()

	--------------------------------------------------------------------------------
	-- Make sure FCPX is at the front.
	--------------------------------------------------------------------------------
	fcp:launch()

	--------------------------------------------------------------------------------
	-- Make sure the panel is open:
	--------------------------------------------------------------------------------
	generators:show()

	if not generators:isShowing() then
		dialog.displayErrorMessage("Unable to display the Titles panel.\n\nError occurred in titles.apply(...)")
		return false
	end

	--------------------------------------------------------------------------------
	-- Make sure there's nothing in the search box:
	--------------------------------------------------------------------------------
	generators:search():clear()

	--------------------------------------------------------------------------------
	-- Click 'All':
	--------------------------------------------------------------------------------
	if category then
		generators:showTitlesCategory(category)
	else
		generators:showAllTitles()
	end

	--------------------------------------------------------------------------------
	-- Make sure "Installed Titles" is selected:
	--------------------------------------------------------------------------------
	generators:showInstalledTitles()

	--------------------------------------------------------------------------------
	-- Perform Search:
	--------------------------------------------------------------------------------
	generators:search():setValue(shortcut)

	--------------------------------------------------------------------------------
	-- Get the list of matching effects
	--------------------------------------------------------------------------------
	local matches = generators:currentItemsUI()
	if not matches or #matches == 0 then
		--------------------------------------------------------------------------------
		-- If Needed, Search Again Without Text Before First Dash:
		--------------------------------------------------------------------------------
		local index = string.find(shortcut, "-")
		if index ~= nil then
			local trimmedShortcut = string.sub(shortcut, index + 2)
			effects:search():setValue(trimmedShortcut)

			matches = generators:currentItemsUI()
			if not matches or #matches == 0 then
				dialog.displayErrorMessage("Unable to find a transition called '"..shortcut.."'.\n\nError occurred in titles.apply(...).")
				return false
			end
		end
	end

	local generator = matches[1]

	--------------------------------------------------------------------------------
	-- Apply the selected Transition:
	--------------------------------------------------------------------------------
	mod.touchbar.hide()

	generators:applyItem(generator)

	-- TODO: HACK: This timer exists to  work around a mouse bug in Hammerspoon Sierra
	timer.doAfter(0.1, function()
		mod.touchbar.show()

		generators:loadLayout(generatorsLayout)
		if browserLayout then browser:loadLayout(browserLayout) end
		if not generatorsShowing then generators:hide() end
	end)

	--- Success!
	return true
end

--------------------------------------------------------------------------------
-- ASSIGN TITLES SHORTCUT:
--------------------------------------------------------------------------------
function mod.assignTitlesShortcut(whichShortcut)

	--------------------------------------------------------------------------------
	-- Was Final Cut Pro Open?
	--------------------------------------------------------------------------------
	local wasFinalCutProOpen = fcp:isFrontmost()

	--------------------------------------------------------------------------------
	-- Get settings:
	--------------------------------------------------------------------------------
	local currentLanguage 			= fcp:currentLanguage()
	local choices 					= action.choices():getChoices()

	--------------------------------------------------------------------------------
	-- Error Checking:
	--------------------------------------------------------------------------------
	if choices == nil or #choices == 0 then
		dialog.displayMessage(i18n("assignTitlesShortcutError"))
		return false
	end

	--------------------------------------------------------------------------------
	-- Sort everything:
	--------------------------------------------------------------------------------
	table.sort(choices, function(a, b)
		return a.text < b.text or a.text == b.text and a.subText < b.subText
	end)

	--------------------------------------------------------------------------------
	-- Setup Chooser:
	--------------------------------------------------------------------------------
	local theChooser = nil
	theChooser = chooser.new(function(result)
		theChooser:hide()
		if result ~= nil then
			--------------------------------------------------------------------------------
			-- Save the selection:
			--------------------------------------------------------------------------------
			mod.setShortcut(whichShortcut, result.params)
		end

		--------------------------------------------------------------------------------
		-- Put focus back in Final Cut Pro:
		--------------------------------------------------------------------------------
		if wasFinalCutProOpen then fcp:launch() end
	end)

	theChooser:bgDark(true):choices(choices):searchSubText(true)

	--------------------------------------------------------------------------------
	-- Allow for Reduce Transparency:
	--------------------------------------------------------------------------------
	if screen.accessibilitySettings()["ReduceTransparency"] then
		theChooser:fgColor(nil)
		          :subTextColor(nil)
	else
		theChooser:fgColor(drawing.color.x11.snow)
 		          :subTextColor(drawing.color.x11.snow)
	end

	--------------------------------------------------------------------------------
	-- Show Chooser:
	--------------------------------------------------------------------------------
	theChooser:show()

	return true
end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
	id = "finalcutpro.timeline.titles",
	group = "finalcutpro",
	dependencies = {
		["finalcutpro.menu.timeline.assignshortcuts"]	= "menu",
		["finalcutpro.commands"]						= "fcpxCmds",
		["finalcutpro.os.touchbar"]						= "touchbar",
		["finalcutpro.action.manager"]					= "actionmanager",
	}
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)
	-- Reset when the language changes.
	fcp.currentLanguage:watch(function(app)
		if app then
			action.reset()
		end
	end)

	mod.touchbar = deps.touchbar

	-- Register the Action
	action.init(deps.actionmanager)

	-- The 'Assign Shortcuts' menu
	local menu = deps.menu:addMenu(PRIORITY, function() return i18n("assignTitlesShortcuts") end)

	menu:addItems(1000, function()
		--------------------------------------------------------------------------------
		-- Shortcuts:
		--------------------------------------------------------------------------------
		local shortcuts		= mod.getShortcuts()

		local items = {}

		for i = 1, MAX_SHORTCUTS do
			local shortcutName = shortcuts[i] or i18n("unassignedTitle")
			items[i] = { title = i18n("titleShortcutTitle", { number = i, title = shortcutName}), fn = function() mod.assignTitlesShortcut(i) end }
		end

		return items
	end)

	-- Commands
	local fcpxCmds = deps.fcpxCmds
	for i = 1, MAX_SHORTCUTS do
		fcpxCmds:add("cpTitles"..tools.numberToWord(i)):whenActivated(function() mod.apply(i) end)
	end

	return mod
end

return plugin
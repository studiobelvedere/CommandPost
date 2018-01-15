local log					= require("hs.logger").new("testfcp")

local fs					= require("hs.fs")

local config				= require("cp.config")
local fcp					= require("cp.apple.finalcutpro")
local ids					= require("cp.apple.finalcutpro.ids")
local just					= require("cp.just")
local test					= require("cp.test")

local TEST_LIBRARY 			= "Test Library.fcpbundle"

local temporaryDirectory 	= fs.temporaryDirectory() .. "CommandPost"
local temporaryLibrary 		= temporaryDirectory .. "/" .. TEST_LIBRARY

local function loadLibrary()
	local output, status = os.execute("open '".. temporaryLibrary .. "'")
	ok(status, output)
end

local function reset()
	fcp:launch()
	fcp:selectMenu({"Window", "Workspaces", "Default"})
	loadLibrary()
	-- keep trying until the library loads successfully, waiting up to 10 seconds.
	just.doUntil(function() return fcp:libraries():selectLibrary("Test Library") ~= nil end, 10.0)
	if not fcp:libraries():openClipTitled("Test Project") then
		error(string.format("Unable to open the 'Test Project' clip."))
	end
end

return test.suite("cp.apple.finalcutpro"):with(
	test("Launch FCP", function()
		-- Launch FCP
		fcp:launch()
		ok(fcp:isRunning(), "FCP is running")
	end),

	test("Check FCP Primary Components", function()
		-- Reset to the default workspace
		reset()

		-- Test that various UI elements are able to be found.
		ok(fcp:primaryWindow():showing())
		ok(fcp:browser():showing())
		ok(fcp:timeline():showing())
		ok(fcp:inspector():showing())
		ok(fcp:viewer():showing())
		ok(not fcp:eventViewer():showing())
	end),

	test("Check Event Viewer", function()
		-- Reset to default workspace
		reset()

		-- Turn it on and off.
		ok(not fcp:eventViewer():showing())
		fcp:eventViewer():showOnPrimary()
		ok(fcp:eventViewer():showing())
		fcp:eventViewer():hide()
		ok(not fcp:eventViewer():showing())
	end),

	test("Command Editor", function()
		reset()

		-- The Command Editor.
		ok(not fcp:commandEditor():showing())
		fcp:commandEditor():show()
		ok(fcp:commandEditor():showing())
		ok(fcp:commandEditor():saveButton():UI() ~= nil)
		fcp:commandEditor():hide()
		ok(not fcp:commandEditor():showing())
	end),

	test("Export Dialog", function()
		reset()

		-- Export Dialog
		ok(not fcp:exportDialog():showing())
		fcp:exportDialog():show()
		ok(fcp:exportDialog():showing())
		fcp:exportDialog():hide()
		ok(not fcp:exportDialog():showing())
	end),

	test("Media Importer", function()
		reset()

		-- Media Importer
		ok(not fcp:mediaImport():showing())
		fcp:mediaImport():show()
		ok(fcp:mediaImport():showing())
		fcp:mediaImport():hide()
		-- The window takes a moment to close sometimes, give it a second.
		just.doWhile(function() return fcp:mediaImport():showing() end, 1.0)
		ok(not fcp:mediaImport():showing())
	end),

	test("Effects Browser", function()
		reset()

		local browser = fcp:effects()
		browser:show()
		ok(browser:showing())
		ok(browser:sidebar():showing())
		ok(browser:contents():showing())
		browser:hide()
		ok(not browser:showing())
	end),

	test("Transitions Browser", function()
		reset()

		local browser = fcp:transitions()
		browser:show()
		ok(browser:showing())
		ok(browser:sidebar():showing())
		ok(browser:contents():showing())
		browser:hide()
		ok(not browser:showing())
	end),

	test("Media Browser", function()
		reset()

		local browser = fcp:media()
		browser:show()
		ok(browser:showing())
		ok(browser:sidebar():showing())
		browser:hide()
		ok(not browser:showing())
	end),

	test("Generators Browser", function()
		reset()

		local browser = fcp:generators()
		browser:show()
		ok(browser:showing())
		ok(browser:sidebar():showing())
		ok(browser:contents():showing())
		browser:hide()
		ok(not browser:showing())
	end),

	test("Inspector", function()
		reset()

		local inspector = fcp:inspector()
		inspector:show()
		just.doUntil(function() return inspector:showing() end, 1)
		ok(inspector:showing())
		inspector:hide()
		ok(not inspector:showing())
	end),

	test("Libraries Browser", function()
		reset()

		-- Show it
		local libraries = fcp:libraries()
		libraries:show()

		-- Check UI elements
		ok(libraries:showing())
		ok(libraries:toggleViewMode():showing())
		ok(libraries:appearanceAndFiltering():showing())
		ok(libraries:sidebar():showing())

		-- Check the search UI
		ok(libraries:searchToggle():showing())
		-- Show the search field if necessary
		if not libraries:search():showing() or not libraries:filterToggle():showing() then
			libraries:searchToggle():press()
		end

		ok(libraries:search():showing())
		ok(libraries:filterToggle():showing())
		-- turn it back off
		libraries:searchToggle():press()
		ok(not libraries:search():showing())
		ok(not libraries:filterToggle():showing())

		-- Check that it hides
		libraries:hide()
		ok(not libraries:showing())
		ok(not libraries:toggleViewMode():showing())
		ok(not libraries:appearanceAndFiltering():showing())
		ok(not libraries:searchToggle():showing())
		ok(not libraries:search():showing())
		ok(not libraries:filterToggle():showing())
	end),

	test("Libraries Filmstrip", function()
		reset()
		local libraries = fcp:libraries()

		-- Check Filmstrip/List view
		libraries:filmstrip():show()
		ok(libraries:filmstrip():showing())
		ok(not libraries:list():showing())
	end),

	test("Libraries List", function()
		reset()
		local libraries = fcp:libraries()
		local list		= libraries:list()

		list:show()
		ok(list:showing())
		ok(not libraries:filmstrip():showing())

		-- Check the sub-components are available.
		ok(list:playerUI() ~= nil)
		ok(list:contents():showing())
		ok(list:clipsUI() ~= nil)
	end),

	test("Timeline", function()
		reset()
		local timeline = fcp:timeline()

		ok(timeline:showing())
		timeline:hide()
		ok(not timeline:showing())
	end),

	test("Timeline Appearance", function()
		reset()
		local appearance = fcp:timeline():toolbar():appearance()

		ok(appearance:toggle():showing())
		ok(not appearance:showing())
		ok(not appearance:clipHeight():showing())

		appearance:show()
		ok(just.doUntil(function() return appearance:showing() end))
		ok(appearance:clipHeight():showing())

		appearance:hide()
		ok(not appearance:showing())
		ok(not appearance:clipHeight():showing())
	end),

	test("Timeline Contents", function()
		reset()
		local contents = fcp:timeline():contents()

		ok(contents:showing())
		ok(contents:scrollAreaUI() ~= nil)
	end),

	test("Timeline Toolbar", function()
		reset()
		local toolbar = fcp:timeline():toolbar()

		ok(toolbar:showing())
		ok(toolbar:skimmingGroupUI() ~= nil)
		ok(toolbar:skimmingGroupUI():attributeValue("AXIdentifier") == ids "TimelineToolbar" "SkimmingGroup")

		ok(toolbar:effectsGroupUI() ~= nil)
		ok(toolbar:effectsGroupUI():attributeValue("AXIdentifier") == ids "TimelineToolbar" "EffectsGroup")

	end),

	test("Viewer", function()
		reset()
		local viewer = fcp:viewer()

		ok(viewer:showing())
		ok(viewer:topToolbarUI() ~= nil)
		ok(viewer:bottomToolbarUI() ~= nil)
		ok(viewer:formatUI() ~= nil)
		ok(viewer:getFramerate() ~= nil)
		ok(viewer:getTitle() ~= nil)
	end),

	test("PreferencesWindow", function()
		reset()
		local prefs = fcp:preferencesWindow()

		prefs:show()
		ok(prefs:showing())

		prefs:hide()
		ok(not prefs:showing())
	end),

	test("ImportPanel", function()
		reset()
		local panel = fcp:preferencesWindow():importPanel()

		-- Make sure the preferences window is hidden
		fcp:preferencesWindow():hide()
		ok(not panel:showing())

		-- Show the import preferences panel
		panel:show()
		ok(panel:showing())
		ok(panel:createProxyMedia():showing())
		ok(panel:createOptimizedMedia():showing())
		ok(panel:copyToMediaFolder():showing())
		ok(panel:leaveInPlace():showing())
		ok(panel:copyToMediaFolder():isChecked() or panel:leaveInPlace():isChecked())

		panel:hide()
	end),

	test("PlaybackPanel", function()
		reset()
		local panel = fcp:preferencesWindow():playbackPanel()

		-- Make sure the preferences window is hidden
		fcp:preferencesWindow():hide()
		ok(not panel:showing())

		-- Show the import preferences panel
		panel:show()
		ok(panel:showing())
		ok(panel:createMulticamOptimizedMedia():showing())
		ok(panel:backgroundRender():showing())

		panel:hide()
	end)
)
-- custom run function, that loops through all languages (or languages provided)
:onRun(function(self, runTests, languages, ...)
	-- Figure out which languages to test
	if type(languages) == "table" then
		languages = languages and #languages > 0 and languages
	elseif type(languages) == "string" then
		languages = { languages }
	elseif languages == nil or languages == true then
		languages = fcp:getSupportedLanguages()
	else
		error(string.format("Unsupported 'languages' filter: %s", languages))
	end

	-- Store the current language:
	local originalLanguage = fcp:currentLanguage()
	local originalName = self.name

	-- Copy Test Library to Temporary Directory:
	local testLibrary = config.scriptPath .. "/tests/fcp/libraries/" .. fcp:getVersion() .. "/" .. TEST_LIBRARY

	fs.rmdir(temporaryDirectory)
	fs.mkdir(temporaryDirectory)
	hs.execute([[cp -R "]] .. testLibrary .. [[" "]] .. temporaryDirectory .. [["]])

	for _,lang in ipairs(languages) do
		-- log.df("Testing FCPX in the '%s' language...", lang)
		self.name = originalName .. " > " .. lang
		if fcp:currentLanguage(lang) then
			just.wait(2)
			fcp:launch()
			just.doUntil(fcp.isRunning)

			-- run the actual tests
			runTests(self, ...)
		else
			log.ef("Unable to set FCPX to use the '%s' language.", lang)
		end
	end

	-- Reset to the current language
	fcp:currentLanguage(originalLanguage)
	self.name = originalName

	-- Quit FCPX and remove Test Library from Temporary Directory:
	-- log.df("Quitting FCPX and deleting Test Library...")
	-- fcp:quit()
	-- fs.rmdir(temporaryDirectory)

end)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                  B A T C H    E X P O R T    P L U G I N                   --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === plugins.finalcutpro.export.batch ===
---
--- Batch Export Plugin

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Logger:
--------------------------------------------------------------------------------
local log           = require("hs.logger").new("batch")

--------------------------------------------------------------------------------
-- Hammerspoon Extensions:
--------------------------------------------------------------------------------
local fnutils       = require("hs.fnutils")
local fs            = require("hs.fs")
local geometry      = require("hs.geometry")
local image         = require("hs.image")
local mouse         = require("hs.mouse")

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local axutils       = require("cp.ui.axutils")
local compressor    = require("cp.apple.compressor")
local config        = require("cp.config")
local dialog        = require("cp.dialog")
local fcp           = require("cp.apple.finalcutpro")
local just          = require("cp.just")
local tools         = require("cp.tools")
local html          = require("cp.web.html")
local ui            = require("cp.web.ui")

--------------------------------------------------------------------------------
--
-- CONSTANTS:
--
--------------------------------------------------------------------------------
local PRIORITY = 2000

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--- plugins.finalcutpro.export.batch.DEFAULT_CUSTOM_FILENAME -> string
--- Constant
--- Default Custom Filename
mod.DEFAULT_CUSTOM_FILENAME = i18n("batchExport")

-- plugins.finalcutpro.export.batch._existingClipNames -> table
-- Variable
-- Table of existing clip names.
mod._existingClipNames = {}

-- plugins.finalcutpro.export.batch._clips -> table
-- Variable
-- Table of clips to batch export.
mod._clips = {}

-- plugins.finalcutpro.export.batch._nextID -> number
-- Variable
-- Next available ID for building the UI.
mod._nextID = 0

--- plugins.finalcutpro.export.batch.replaceExistingFiles <cp.prop: boolean>
--- Field
--- Defines whether or not a Batch Export should Replace Existing Files.
mod.replaceExistingFiles = config.prop("batchExportReplaceExistingFiles", false)

--- plugins.finalcutpro.export.batch.useCustomFilename <cp.prop: boolean>
--- Field
--- Defines whether or not the Batch Export tool should override the clipname with a custom filename.
mod.useCustomFilename = config.prop("batchExportOverrideClipnameWithCustomFilename", false)

--- plugins.finalcutpro.export.batch.customFilename <cp.prop: string>
--- Field
--- Custom Filename for Batch Export.
mod.customFilename = config.prop("batchExportCustomFilename", mod.DEFAULT_CUSTOM_FILENAME)

--- plugins.finalcutpro.export.batch.ignoreMissingEffects <cp.prop: boolean>
--- Field
--- Defines whether or not a Batch Export should Ignore Missing Effects.
mod.ignoreMissingEffects = config.prop("batchExportIgnoreMissingEffects", false)

--- plugins.finalcutpro.export.batch.ignoreProxies <cp.prop: boolean>
--- Field
--- Defines whether or not a Batch Export should Ignore Proxies.
mod.ignoreProxies = config.prop("batchExportIgnoreProxies", false)

-- selectShare() -> boolean
-- Function
-- Select Share Destination from the Final Cut Pro Menubar
--
-- Parameters:
--  * None
--
-- Returns:
--  * `true` if successful otherwise `false`
local function selectShare(destinationPreset)
    return fcp:selectMenu({"File", "Share", function(menuItem)
        if destinationPreset == nil then
            return menuItem:attributeValue("AXMenuItemCmdChar") ~= nil
        else
            local title = menuItem:attributeValue("AXTitle")
            return title and string.find(title, destinationPreset, 1, true) ~= nil
        end
    end})
end

--- plugins.finalcutpro.export.batch.sendTimelineClipsToCompressor(clips) -> boolean
--- Function
--- Send Timeline Clips to Compressor.
---
--- Parameters:
---  * clips - table of selected Clips
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.sendTimelineClipsToCompressor(clips)

    --------------------------------------------------------------------------------
    -- Launch Compressor:
    --------------------------------------------------------------------------------
    local result
    if not compressor:isRunning() then
        result = just.doUntil(function()
            compressor:launch()
            return compressor:isFrontmost()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to Launch Compressor.")
            return false
        end
    end

    --------------------------------------------------------------------------------
    -- Make sure Final Cut Pro is Active:
    --------------------------------------------------------------------------------
    result = just.doUntil(function()
        fcp:launch()
        return fcp:isFrontmost()
    end, 10, 0.1)
    if not result then
        dialog.displayErrorMessage("Failed to switch back to Final Cut Pro.")
        return false
    end

    --------------------------------------------------------------------------------
    -- Make sure the Timeline is selected:
    --------------------------------------------------------------------------------
    if not fcp:selectMenu({"Window", "Go To", "Timeline"}) then
        dialog.displayErrorMessage("Could not trigger 'Go To Timeline'.")
        return false
    end

    --------------------------------------------------------------------------------
    -- Process each clip individually:
    --------------------------------------------------------------------------------
    local playhead = fcp:timeline():playhead()
    local timelineContents = fcp:timeline():contents()
    for _,clip in tools.spairs(clips, function(t,a,b) return t[a]:attributeValue("AXValueDescription") < t[b]:attributeValue("AXValueDescription") end) do

        --------------------------------------------------------------------------------
        -- Make sure Final Cut Pro is Active:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            fcp:launch()
            return fcp:isFrontmost()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to switch back to Final Cut Pro.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Make sure the Timeline is selected:
        --------------------------------------------------------------------------------
        if not fcp:selectMenu({"Window", "Go To", "Timeline"}) then
            dialog.displayErrorMessage("Could not trigger 'Go To Timeline'.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Get Start Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            timelineContents:selectClip(clip)
            local selectedClips = timelineContents:selectedClipsUI()
            return selectedClips and #selectedClips == 1 and selectedClips[1] == clip
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to select clip during start timecode phase.")
            return false
        end
        if not fcp:selectMenu({"Mark", "Go to", "Range Start"}) then
            dialog.displayErrorMessage("Could not trigger 'Range Start'.")
            return false
        end
        local startTimecode = playhead:getTimecode()
        if not startTimecode then
            dialog.displayErrorMessage("Could not get start timecode for clip.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Get End Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            timelineContents:selectClip(clip)
            local selectedClips = timelineContents:selectedClipsUI()
            return selectedClips and #selectedClips == 1 and selectedClips[1] == clip
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to select clip during end timecode phase.")
            return false
        end
        if not fcp:selectMenu({"Mark", "Go to", "Range End"}) then
            dialog.displayErrorMessage("Could not trigger 'Range End'.")
            return false
        end
        local endTimecode = playhead:getTimecode()
        if not endTimecode then
            dialog.displayErrorMessage("Could not get end timecode for clip.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Set Start Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            playhead:setTimecode(startTimecode)
            local currentTimecode = playhead:getTimecode()
            return startTimecode and currentTimecode and startTimecode == currentTimecode
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to goto start timecode.")
            return false
        end
        if not fcp:selectMenu({"Mark", "Set Range Start"}) then
            dialog.displayErrorMessage("Could not trigger 'Set Range Start'.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Set End Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            playhead:setTimecode(endTimecode)
            local currentTimecode = playhead:getTimecode()
            return endTimecode and currentTimecode and endTimecode == currentTimecode
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to goto end timecode.")
            return false
        end
        if not fcp:selectMenu({"Mark", "Set Range End"}) then
            dialog.displayErrorMessage("Could not trigger 'Set Range End'.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Make sure the Timeline is selected:
        --------------------------------------------------------------------------------
        if not fcp:selectMenu({"Window", "Go To", "Timeline"}) then
            dialog.displayErrorMessage("Could not trigger 'Go To Timeline'.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Trigger Export:
        --------------------------------------------------------------------------------
        if not fcp:selectMenu({"File", "Send to Compressor"}) then
            dialog.displayErrorMessage("Could not trigger 'Send to Compressor'.")
            return false
        end

    end
    return true

end

--- plugins.finalcutpro.export.batch.sendBrowserClipsToCompressor(clips) -> boolean
--- Function
--- Send Clips to Compressor
---
--- Parameters:
---  * clips - table of selected Clips
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.sendBrowserClipsToCompressor(clips)

    --------------------------------------------------------------------------------
    -- Launch Compressor:
    --------------------------------------------------------------------------------
    if not compressor:isRunning() then
        local result = just.doUntil(function()
            compressor:launch()
            return compressor:isFrontmost()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to Launch Compressor.")
            return false
        end
    end

    --------------------------------------------------------------------------------
    -- Export individual clips:
    --------------------------------------------------------------------------------
    local libraries = fcp:browser():libraries()
    for _,clip in ipairs(clips) do

        --------------------------------------------------------------------------------
        -- Make sure Final Cut Pro is Active:
        --------------------------------------------------------------------------------
        local result = just.doUntil(function()
            fcp:launch()
            return fcp:isFrontmost()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to switch back to Final Cut Pro.\n\nThis shouldn't happen.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Make sure Libraries panel is focussed:
        --------------------------------------------------------------------------------
        fcp:selectMenu({"Window", "Go To", "Libraries"})

        --------------------------------------------------------------------------------
        -- Select Item:
        --------------------------------------------------------------------------------
        libraries:selectClip(clip)

        --------------------------------------------------------------------------------
        -- Make sure the Library is selected:
        --------------------------------------------------------------------------------
        if not fcp:selectMenu({"Window", "Go To", "Libraries"}) then
            dialog.displayErrorMessage("Could not trigger 'Go To Libraries'.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Trigger Export:
        --------------------------------------------------------------------------------
        if not fcp:selectMenu({"File", "Send to Compressor"}) then
            dialog.displayErrorMessage("Could not trigger 'Send to Compressor'.")
            return false
        end

    end
    return true

end

--- plugins.finalcutpro.export.batch.batchExportBrowserClips(clips) -> boolean
--- Function
--- Batch Export Clips
---
--- Parameters:
---  * clips - table of selected Clips
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.batchExportBrowserClips(clips)

    --------------------------------------------------------------------------------
    -- Setup:
    --------------------------------------------------------------------------------
    local result
    local firstTime             = true
    local libraries             = fcp:browser():libraries()
    local exportPath            = mod.getDestinationFolder()
    local destinationPreset     = mod.getDestinationPreset()
    local errorFunction         = "\n\nError occurred in batchExportBrowserClips()."

    --------------------------------------------------------------------------------
    -- Process individual clips:
    --------------------------------------------------------------------------------
    for _,clip in ipairs(clips) do

        --------------------------------------------------------------------------------
        -- Make sure Final Cut Pro is Active:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            fcp:launch()
            return fcp:isFrontmost()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to switch back to Final Cut Pro.\n\nThis shouldn't happen.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Make sure Libraries panel is focussed:
        --------------------------------------------------------------------------------
        fcp:selectMenu({"Window", "Go To", "Libraries"})

        --------------------------------------------------------------------------------
        -- Select Item:
        --------------------------------------------------------------------------------
        libraries:selectClip(clip)

        --------------------------------------------------------------------------------
        -- Get Clip Name:
        --------------------------------------------------------------------------------
        local clipName = clip:getTitle()
        if not clipName then
            dialog.displayErrorMessage("Could not get clip name." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Trigger Export:
        --------------------------------------------------------------------------------
        if not selectShare(destinationPreset) then
            dialog.displayErrorMessage("Could not trigger Share Menu Item." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Wait for Export Dialog to open:
        --------------------------------------------------------------------------------
        local exportDialog = fcp:exportDialog()

        --------------------------------------------------------------------------------
        -- Handle this dialog box:
        --
        -- This project is currently set to use proxy media.
        -- FFShareProxyPlaybackEnabledMessageText
        --------------------------------------------------------------------------------
        if not just.doUntil(function() return exportDialog:isShowing() end) then
            local windowUIs = fcp:windowsUI()
            if windowUIs then
                for _, windowUI in pairs(windowUIs) do
                    local sheets = axutils.childrenWithRole(windowUI, "AXSheet")
                    if sheets then
                        for _, sheet in pairs(sheets) do
                            local continueButton = axutils.childWith(sheet, "AXTitle", fcp:string("FFMissingMediaDefaultButtonText"))
                            local matchingSheet = axutils.childrenMatching(sheet, function(child)
                                if child and child:attributeValue("AXRole") == "AXStaticText" and child:attributeValue("AXValue") == fcp:string("FFShareProxyPlaybackEnabledMessageText") then
                                    return child
                                end
                            end)
                            if matchingSheet and #matchingSheet == 1 and continueButton then
                                if mod.ignoreProxies() then
                                    --------------------------------------------------------------------------------
                                    -- Press the 'Continue' button:
                                    --------------------------------------------------------------------------------
                                    continueButton:performAction("AXPress")
                                else
                                    dialog.displayMessage(i18n("batchExportProxyFilesDetected"))
                                    return false
                                end
                            end
                        end
                    end
                end
            end
        end

        --------------------------------------------------------------------------------
        -- Handle this dialog box:
        --
        -- “%@” has missing or offline titles, effects, generators, or media.
        -- FFMissingMediaMessageText
        --------------------------------------------------------------------------------
        if not just.doUntil(function() return exportDialog:isShowing() end) then
            local triggerError = true
            local windowUIs = fcp:windowsUI()
            if windowUIs then
                for _, windowUI in pairs(windowUIs) do
                    local sheets = axutils.childrenWithRole(windowUI, "AXSheet")
                    if sheets then
                        for _, sheet in pairs(sheets) do
                            local continueButton = axutils.childWith(sheet, "AXTitle", fcp:string("FFMissingMediaDefaultButtonText"))
                            local matchingSheet = axutils.childrenMatching(sheet, function(child)
                                if child and child:attributeValue("AXRole") == "AXStaticText" and string.find(child:attributeValue("AXValue"), string.gsub(fcp:string("FFMissingMediaMessageText"), [[“%%@” ]], "")) then
                                    return child
                                end
                            end)
                            if matchingSheet and #matchingSheet == 1 and continueButton then
                                if mod.ignoreMissingEffects() then
                                    --------------------------------------------------------------------------------
                                    -- Press the 'Continue' button:
                                    --------------------------------------------------------------------------------
                                    result = continueButton:performAction("AXPress")
                                    if result ~= nil then
                                        triggerError = false
                                    end
                                else
                                    dialog.displayMessage(i18n("batchExportMissingFilesDetected"))
                                    return false
                                end
                            end
                        end
                    end
                end
            end
            if triggerError then
                dialog.displayErrorMessage("Failed to open the 'Export' window." .. errorFunction)
                return false
            end
        end

        --------------------------------------------------------------------------------
        -- Press 'Next':
        --------------------------------------------------------------------------------
        exportDialog:pressNext()

        --------------------------------------------------------------------------------
        -- If 'Next' has been clicked (as opposed to 'Share'):
        --------------------------------------------------------------------------------
        local saveSheet = exportDialog:saveSheet()
        if exportDialog:isShowing() then

            --------------------------------------------------------------------------------
            -- Click 'Save' on the save sheet:
            --------------------------------------------------------------------------------
            if not just.doUntil(function() return saveSheet:isShowing() end) then
                dialog.displayErrorMessage("Failed to open the 'Save' window." .. errorFunction)
                return false
            end

            --------------------------------------------------------------------------------
            -- Set Custom Export Path (or Default to Desktop):
            --------------------------------------------------------------------------------
            if firstTime then
                saveSheet:setPath(exportPath)
                firstTime = false
            end

            --------------------------------------------------------------------------------
            -- Make sure we don't already have a clip with the same name in the batch:
            --------------------------------------------------------------------------------
            local filename = saveSheet:filename():getValue()
            if filename then
                local newFilename = clipName

                --------------------------------------------------------------------------------
                -- Inject Custom Filenames:
                --------------------------------------------------------------------------------
                local customFilename = mod.customFilename()
                local useCustomFilename = mod.useCustomFilename()
                if useCustomFilename and customFilename then
                    newFilename = customFilename
                end

                while fnutils.contains(mod._existingClipNames, newFilename) do
                    newFilename = tools.incrementFilename(newFilename)
                end
                if filename ~= newFilename then
                    saveSheet:filename():setValue(newFilename)
                end
                table.insert(mod._existingClipNames, newFilename)
            end

            --------------------------------------------------------------------------------
            -- Click 'Save' on the save sheet:
            --------------------------------------------------------------------------------
            saveSheet:pressSave()

        end

        --------------------------------------------------------------------------------
        -- Make sure Save Window is closed:
        --------------------------------------------------------------------------------
        while saveSheet:isShowing() do
            local replaceAlert = saveSheet:replaceAlert()
            if mod.replaceExistingFiles() and replaceAlert:isShowing() then
                replaceAlert:pressReplace()
            else
                replaceAlert:pressCancel()

                local originalFilename = saveSheet:filename():getValue()
                if originalFilename == nil then
                    dialog.displayErrorMessage("Failed to get the original Filename." .. errorFunction)
                    return false
                end

                local newFilename = tools.incrementFilename(originalFilename)

                saveSheet:filename():setValue(newFilename)
                saveSheet:pressSave()
            end
        end

    end
    return true
end

--- plugins.finalcutpro.export.batch.batchExportTimelineClips(clips) -> boolean
--- Function
--- Batch Export Timeline Clips
---
--- Parameters:
---  * clips - table of selected Clips
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.batchExportTimelineClips(clips)

    --------------------------------------------------------------------------------
    -- Setup:
    --------------------------------------------------------------------------------
    local result
    local firstTime             = true
    local exportPath            = mod.getDestinationFolder()
    local destinationPreset     = mod.getDestinationPreset()
    local errorFunction         = "\n\nError occurred in batchExportTimelineClips()."

    --------------------------------------------------------------------------------
    -- Process each clip individually:
    --------------------------------------------------------------------------------
    local playhead = fcp:timeline():playhead()
    local timelineContents = fcp:timeline():contents()
    for _,clip in tools.spairs(clips, function(t,a,b) return t[a]:attributeValue("AXValueDescription") < t[b]:attributeValue("AXValueDescription") end) do

        --------------------------------------------------------------------------------
        -- Make sure Final Cut Pro is Active:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            fcp:launch()
            return fcp:isFrontmost()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to switch back to Final Cut Pro." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Make sure the Timeline is selected:
        --------------------------------------------------------------------------------
        if not fcp:selectMenu({"Window", "Go To", "Timeline"}) then
            dialog.displayErrorMessage("Could not trigger 'Go To Timeline'." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Select clip:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            timelineContents:selectClip(clip)
            local selectedClips = timelineContents:selectedClipsUI()
            return selectedClips and #selectedClips == 1 and selectedClips[1] == clip
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to select clip during start timecode phase." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Get Clip Name whilst we're at it:
        --------------------------------------------------------------------------------
        local clipName = clip:attributeValue("AXDescription")
        if not clipName then
            dialog.displayErrorMessage("Could not get clip name." .. errorFunction)
            return false
        end
        local columnPostion = string.find(clipName, ":")
        if columnPostion then
            clipName = string.sub(clipName, columnPostion + 1)
        end

        --------------------------------------------------------------------------------
        -- Get Start Timecode:
        --------------------------------------------------------------------------------
        if not fcp:selectMenu({"Mark", "Go to", "Range Start"}) then
            dialog.displayErrorMessage("Could not trigger 'Range Start'." .. errorFunction)
            return false
        end
        local startTimecode = playhead:getTimecode()
        if not startTimecode then
            dialog.displayErrorMessage("Could not get start timecode for clip." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Get End Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            timelineContents:selectClip(clip)
            local selectedClips = timelineContents:selectedClipsUI()
            return selectedClips and #selectedClips == 1 and selectedClips[1] == clip
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to select clip during end timecode phase." .. errorFunction)
            return false
        end
        if not fcp:selectMenu({"Mark", "Go to", "Range End"}) then
            dialog.displayErrorMessage("Could not trigger 'Range End'." .. errorFunction)
            return false
        end
        local endTimecode = playhead:getTimecode()
        if not endTimecode then
            dialog.displayErrorMessage("Could not get end timecode for clip." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Set Start Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            playhead:setTimecode(startTimecode)
            local currentTimecode = playhead:getTimecode()
            return startTimecode and currentTimecode and startTimecode == currentTimecode
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to goto start timecode.")
            return false
        end
        if not fcp:selectMenu({"Mark", "Set Range Start"}) then
            dialog.displayErrorMessage("Could not trigger 'Set Range Start'." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Set End Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            playhead:setTimecode(endTimecode)
            local currentTimecode = playhead:getTimecode()
            return endTimecode and currentTimecode and endTimecode == currentTimecode
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to goto end timecode.")
            return false
        end
        if not fcp:selectMenu({"Mark", "Set Range End"}) then
            dialog.displayErrorMessage("Could not trigger 'Set Range End'." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Make sure the Timeline is selected:
        --------------------------------------------------------------------------------
        if not fcp:selectMenu({"Window", "Go To", "Timeline"}) then
            dialog.displayErrorMessage("Could not trigger 'Go To Timeline'." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Trigger Export:
        --------------------------------------------------------------------------------
        if not selectShare(destinationPreset) then
            dialog.displayErrorMessage("Could not trigger Share Menu Item." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Wait for Export Dialog to open:
        --------------------------------------------------------------------------------
        local exportDialog = fcp:exportDialog()

        --------------------------------------------------------------------------------
        -- Handle this dialog box:
        --
        -- This project is currently set to use proxy media.
        -- FFShareProxyPlaybackEnabledMessageText
        --------------------------------------------------------------------------------
        if not just.doUntil(function() return exportDialog:isShowing() end) then
            local windowUIs = fcp:windowsUI()
            if windowUIs then
                for _, windowUI in pairs(windowUIs) do
                    local sheets = axutils.childrenWithRole(windowUI, "AXSheet")
                    if sheets then
                        for _, sheet in pairs(sheets) do
                            local continueButton = axutils.childWith(sheet, "AXTitle", fcp:string("FFMissingMediaDefaultButtonText"))
                            local matchingSheet = axutils.childrenMatching(sheet, function(child)
                                if child and child:attributeValue("AXRole") == "AXStaticText" and child:attributeValue("AXValue") == fcp:string("FFShareProxyPlaybackEnabledMessageText") then
                                    return child
                                end
                            end)
                            if matchingSheet and #matchingSheet == 1 and continueButton then
                                if mod.ignoreProxies() then
                                    --------------------------------------------------------------------------------
                                    -- Press the 'Continue' button:
                                    --------------------------------------------------------------------------------
                                    continueButton:performAction("AXPress")
                                else
                                    dialog.displayMessage(i18n("batchExportProxyFilesDetected"))
                                    return false
                                end
                            end
                        end
                    end
                end
            end
        end

        --------------------------------------------------------------------------------
        -- Handle this dialog box:
        --
        -- “%@” has missing or offline titles, effects, generators, or media.
        -- FFMissingMediaMessageText
        --------------------------------------------------------------------------------
        if not just.doUntil(function() return exportDialog:isShowing() end) then
            local triggerError = true
            local windowUIs = fcp:windowsUI()
            if windowUIs then
                for _, windowUI in pairs(windowUIs) do
                    local sheets = axutils.childrenWithRole(windowUI, "AXSheet")
                    if sheets then
                        for _, sheet in pairs(sheets) do
                            local continueButton = axutils.childWith(sheet, "AXTitle", fcp:string("FFMissingMediaDefaultButtonText"))
                            local matchingSheet = axutils.childrenMatching(sheet, function(child)
                                if child and child:attributeValue("AXRole") == "AXStaticText" and string.find(child:attributeValue("AXValue"), string.gsub(fcp:string("FFMissingMediaMessageText"), [[“%%@” ]], "")) then
                                    return child
                                end
                            end)
                            if matchingSheet and #matchingSheet == 1 and continueButton then
                                if mod.ignoreMissingEffects() then
                                    --------------------------------------------------------------------------------
                                    -- Press the 'Continue' button:
                                    --------------------------------------------------------------------------------
                                    result = continueButton:performAction("AXPress")
                                    if result ~= nil then
                                        triggerError = false
                                    end
                                else
                                    dialog.displayMessage(i18n("batchExportMissingFilesDetected"))
                                    return false
                                end
                            end
                        end
                    end
                end
            end
            if triggerError then
                dialog.displayErrorMessage("Failed to open the 'Export' window." .. errorFunction)
                return false
            end
        end

        --------------------------------------------------------------------------------
        -- Press 'Next':
        --------------------------------------------------------------------------------
        exportDialog:pressNext()

        --------------------------------------------------------------------------------
        -- If 'Next' has been clicked (as opposed to 'Share'):
        --------------------------------------------------------------------------------
        local saveSheet = exportDialog:saveSheet()
        if exportDialog:isShowing() then

            --------------------------------------------------------------------------------
            -- Click 'Save' on the save sheet:
            --------------------------------------------------------------------------------
            if not just.doUntil(function() return saveSheet:isShowing() end) then
                dialog.displayErrorMessage("Failed to open the 'Save' window." .. errorFunction)
                return false
            end

            --------------------------------------------------------------------------------
            -- Set Custom Export Path (or Default to Desktop):
            --------------------------------------------------------------------------------
            if firstTime then
                saveSheet:setPath(exportPath)
                firstTime = false
            end

            --------------------------------------------------------------------------------
            -- Make sure we don't already have a clip with the same name in the batch:
            --------------------------------------------------------------------------------
            local filename = saveSheet:filename():getValue()
            if filename then
                local newFilename = clipName

                --------------------------------------------------------------------------------
                -- Inject Custom Filenames:
                --------------------------------------------------------------------------------
                local customFilename = mod.customFilename()
                local useCustomFilename = mod.useCustomFilename()
                if useCustomFilename and customFilename then
                    newFilename = customFilename
                end

                while fnutils.contains(mod._existingClipNames, newFilename) do
                    newFilename = tools.incrementFilename(newFilename)
                end
                if filename ~= newFilename then
                    saveSheet:filename():setValue(newFilename)
                end
                table.insert(mod._existingClipNames, newFilename)
            end

            --------------------------------------------------------------------------------
            -- Click 'Save' on the save sheet:
            --------------------------------------------------------------------------------
            saveSheet:pressSave()

        end

        --------------------------------------------------------------------------------
        -- Make sure Save Window is closed:
        --------------------------------------------------------------------------------
        while saveSheet:isShowing() do
            local replaceAlert = saveSheet:replaceAlert()
            if mod.replaceExistingFiles() and replaceAlert:isShowing() then
                replaceAlert:pressReplace()
            else
                replaceAlert:pressCancel()

                local originalFilename = saveSheet:filename():getValue()
                if originalFilename == nil then
                    dialog.displayErrorMessage("Failed to get the original Filename." .. errorFunction)
                    return false
                end

                local newFilename = tools.incrementFilename(originalFilename)

                saveSheet:filename():setValue(newFilename)
                saveSheet:pressSave()
            end
        end

    end
    return true
end

--- plugins.finalcutpro.export.batch.changeExportDestinationPreset() -> boolean
--- Function
--- Change Export Destination Preset.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.changeExportDestinationPreset()

    if not fcp:isRunning() then
        dialog.displayMessage(i18n("batchExportFinalCutProClosed"))
        return false
    end

    local shareMenuItems = fcp:menuBar():findMenuItemsUI({"File", "Share"})
    if not shareMenuItems then
        dialog.displayErrorMessage(i18n("batchExportDestinationsNotFound"))
        return false
    end

    local destinations = {}

    if compressor:isInstalled() then
        destinations[#destinations + 1] = i18n("sendToCompressor")
    end

    for i = 1, #shareMenuItems-2 do
        local item = shareMenuItems[i]
        local title = item:attributeValue("AXTitle")
        if title ~= nil then
            local value = string.sub(title, 1, -4)
            --------------------------------------------------------------------------------
            -- It's the default:
            --------------------------------------------------------------------------------
            if item:attributeValue("AXMenuItemCmdChar") then
                --------------------------------------------------------------------------------
                -- Remove (default) text:
                --------------------------------------------------------------------------------
                local firstBracket = string.find(value, " %(", 1)
                if firstBracket == nil then
                    firstBracket = string.find(value, "（", 1)
                end
                value = string.sub(value, 1, firstBracket - 1)
            end
            destinations[#destinations + 1] = value
        end
    end

    local batchExportDestinationPreset = config.get("batchExportDestinationPreset")
    local defaultItems = {}
    if batchExportDestinationPreset ~= nil then defaultItems[1] = batchExportDestinationPreset end

    local result = dialog.displayChooseFromList(i18n("selectDestinationPreset"), destinations, defaultItems)
    if result and #result > 0 then
        config.set("batchExportDestinationPreset", result[1])
    end

    --------------------------------------------------------------------------------
    -- Refresh the Preferences:
    --------------------------------------------------------------------------------
    mod._bmMan.refresh()

    return true
end

--- plugins.finalcutpro.export.batch.changeExportDestinationFolder() -> boolean
--- Function
--- Change Export Destination Folder.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.changeExportDestinationFolder()
    local result = dialog.displayChooseFolder(i18n("selectDestinationFolder"))
    if result == false then return false end
    config.set("batchExportDestinationFolder", result)

    --------------------------------------------------------------------------------
    -- Refresh the Preferences:
    --------------------------------------------------------------------------------
    mod._bmMan.refresh()

    return true
end

--- plugins.finalcutpro.export.batch.changeCustomFilename() -> boolean
--- Function
--- Change Custom Filename String.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.changeCustomFilename()
    local result = mod.customFilename(dialog.displayTextBoxMessage(i18n("enterCustomFilename") .. ":", i18n("enterCustomFilenameError"), mod.customFilename(), function(value)
        if value and type("value") == "string" and value ~= tools.trim("") and tools.safeFilename(value, value) == value then
            return true
        else
            return false
        end
    end))
    if type(result) == "string" then
        mod.customFilename(result)
    end

    --------------------------------------------------------------------------------
    -- Refresh the Preferences:
    --------------------------------------------------------------------------------
    mod._bmMan.refresh()

    return true
end

--- plugins.finalcutpro.export.batch.getDestinationFolder() -> string
--- Function
--- Gets the destination folder path.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The destination folder path as a string.
function mod.getDestinationFolder()
    local batchExportDestinationFolder = config.get("batchExportDestinationFolder")
    local NSNavLastRootDirectory = fcp:getPreference("NSNavLastRootDirectory")
    local exportPath = os.getenv("HOME") .. "/Desktop"
    if batchExportDestinationFolder ~= nil then
         if tools.doesDirectoryExist(batchExportDestinationFolder) then
            exportPath = batchExportDestinationFolder
         end
    else
        if tools.doesDirectoryExist(NSNavLastRootDirectory) then
            exportPath = NSNavLastRootDirectory
        end
    end
    return exportPath and fs.pathToAbsolute(exportPath)
end

--- plugins.finalcutpro.export.batch.getDestinationFolder() -> string | nil
--- Function
--- Gets the destination preset.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The destination preset as a string, or `nil` if no preset is set.
function mod.getDestinationPreset()

    local destinationPreset = config.get("batchExportDestinationPreset")

    if destinationPreset == i18n("sendToCompressor") then
        if not compressor:isInstalled() then
            log.df("Apple Compressor could not be detected.")
            destinationPreset = nil
            config.set("batchExportDestinationPreset", nil)
        end
    end

    if destinationPreset == nil then

        local defaultItem = fcp:menuBar():findMenuUI({"File", "Share", function(menuItem)
            return menuItem:attributeValue("AXMenuItemCmdChar") ~= nil
        end})

        if defaultItem == nil then
            --------------------------------------------------------------------------------
            -- If that fails, get the first item on the list...
            --------------------------------------------------------------------------------
            local firstItem = fcp:menuBar():findMenuUI({"File", "Share", function()
                return true
            end})
            if firstItem and firstItem:attributeValue("AXTitle") then
                destinationPreset = string.sub(firstItem:attributeValue("AXTitle"), 1, -4)
            else
                --------------------------------------------------------------------------------
                -- If all else fails, we'll use "Send To Compressor":
                --------------------------------------------------------------------------------
                if compressor:isInstalled() then
                    destinationPreset = i18n("sendToCompressor")
                else
                    --------------------------------------------------------------------------------
                    -- No options left!
                    --------------------------------------------------------------------------------
                    destinationPreset = nil
                end
            end
        else
            --------------------------------------------------------------------------------
            -- Trim the trailing '(default)…'
            --------------------------------------------------------------------------------
            destinationPreset = defaultItem:attributeValue("AXTitle"):match("(.*) %([^()]+%)…$")
        end

    end
    return destinationPreset
end

--- plugins.finalcutpro.export.batch.batchExport() -> boolean
--- Function
--- Opens the Batch Export popup.
---
--- Parameters:
---  * mode - "timeline" or "browser". If no mode is specified then we will determine
---           the mode based off the mouse location.
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.batchExport(mode)

    --------------------------------------------------------------------------------
    -- Make sure Final Cut Pro is Active:
    --------------------------------------------------------------------------------
    local result = just.doUntil(function()
        fcp:launch()
        return fcp:isFrontmost()
    end, 10, 0.1)
    if not result then
        dialog.displayErrorMessage("Failed to activate Final Cut Pro. Batch Export aborted.")
        return false
    end

    --------------------------------------------------------------------------------
    -- Reset Everything:
    --------------------------------------------------------------------------------
    mod._clips = nil
    mod._existingClipNames = nil
    mod._existingClipNames = {}

    --------------------------------------------------------------------------------
    -- Check where the mouse is, and set panel accordingly:
    --------------------------------------------------------------------------------
    local browser, timeline = fcp:browser(), fcp:timeline()
    if not mode then
        local mouseLocation = geometry.point(mouse.getAbsolutePosition())
        if timeline:isShowing() then
            local timelineViewFrame = timeline:contents():viewFrame()
            if timelineViewFrame then
                if mouseLocation:inside(geometry.rect(timelineViewFrame)) then
                    mode = "timeline"
                end
            end
        end
        if browser:isShowing() and browser:libraries():isShowing() then
            local browserFrame = browser:UI() and browser:UI():frame()
            if browserFrame then
                if mouseLocation:inside(geometry.rect(browserFrame)) then
                    mode = "browser"
                end
            end
        end
    end

    --------------------------------------------------------------------------------
    -- Ignore if mouse is not over browser or timeline:
    --------------------------------------------------------------------------------
    if mode == nil then
        dialog.displayMessage(i18n("batchExportModeError"))
        return
    end

    --------------------------------------------------------------------------------
    -- If the mouse is over the browser:
    --------------------------------------------------------------------------------
    if mode == "browser" then

        --------------------------------------------------------------------------------
        -- Setup Window:
        --------------------------------------------------------------------------------
        mod._bmMan.disabledPanels({"timeline"})
        mod._bmMan.lastTab("browser")

        --------------------------------------------------------------------------------
        -- Check if we have any currently-selected clips:
        --------------------------------------------------------------------------------
        local libraries = browser:libraries()
        local clips = libraries:selectedClips()

        if libraries:sidebar():isFocused() then
            --------------------------------------------------------------------------------
            -- Use All Clips:
            --------------------------------------------------------------------------------
            clips = libraries:clips()
        end

        if clips and #clips > 0 then
            mod._clips =  clips
            mod._bmMan.show()
        else
            --------------------------------------------------------------------------------
            -- No clips selected so ignore:
            --------------------------------------------------------------------------------
            dialog.displayMessage(i18n("batchExportNoClipsInBrowser"))
            return
        end
    end

    --------------------------------------------------------------------------------
    -- If the mouse is over the timeline:
    --------------------------------------------------------------------------------
    if mode == "timeline" then

        --------------------------------------------------------------------------------
        -- Setup Window:
        --------------------------------------------------------------------------------
        mod._bmMan.disabledPanels({"browser"})
        mod._bmMan.lastTab("timeline")

        --------------------------------------------------------------------------------
        -- Check if we have any currently-selected clips:
        --------------------------------------------------------------------------------
        local timelineContents = fcp:timeline():contents()
        local selectedClips = timelineContents:selectedClipsUI()

        if not selectedClips or #selectedClips == 0 then
            dialog.displayMessage(i18n("batchExportNoClipsInTimeline"))
            return
        end

        mod._clips = selectedClips
        mod._bmMan.show()
    end

end

-- clipsToCountString(clips) -> string
-- Function
-- Calculates the numbers of clips supplied and returns the number as a formatted string.
--
-- Parameters:
--  * clips - A table of clips
--
-- Returns:
--  * A string.
local function clipsToCountString(clips)
    local countText = " "
    if clips and #clips > 1 then countText = " " .. tostring(#clips) .. " " end
    return countText
end

--- plugins.finalcutpro.export.batch.performBatchExport() -> none
--- Function
--- Performs the Browser Batch Export function.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.performBatchExport(mode)

    --------------------------------------------------------------------------------
    -- Hide the Window:
    --------------------------------------------------------------------------------
    mod._bmMan.hide()

    --------------------------------------------------------------------------------
    -- Export the clips:
    --------------------------------------------------------------------------------
    local result
    local destinationPreset = mod.getDestinationPreset()
    if destinationPreset == i18n("sendToCompressor") then
        if mode == "browser" then
            result = mod.sendBrowserClipsToCompressor(mod._clips)
        else
            result = mod.sendTimelineClipsToCompressor(mod._clips)
        end
    else
        if mode == "browser" then
            result = mod.batchExportBrowserClips(mod._clips)
        else
            result = mod.batchExportTimelineClips(mod._clips)
        end
    end

    --------------------------------------------------------------------------------
    -- Batch Export Complete:
    --------------------------------------------------------------------------------
    if result then
        dialog.displayMessage(i18n("batchExportComplete"), {i18n("done")})
    end

end

-- nextID() -> number
-- Function
-- Returns the next free ID.
--
-- Parameters:
--  * None
--
-- Returns:
--  * The next ID as a number.
local function nextID()
    mod._nextID = mod._nextID + 1
    return mod._nextID
end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id              = "finalcutpro.export.batch",
    group           = "finalcutpro",
    dependencies    = {
        ["core.menu.manager"]                   = "manager",
        ["finalcutpro.menu.tools"]              = "prefs",
        ["finalcutpro.commands"]                = "fcpxCmds",
        ["finalcutpro.export.batch.manager"]    = "batchExportManager",
    }
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)

    --------------------------------------------------------------------------------
    -- Create the Batch Export window:
    --------------------------------------------------------------------------------
    mod._bmMan = deps.batchExportManager
    local fcpPath = fcp:getPath() or ""

    --------------------------------------------------------------------------------
    -- Browser Panel:
    --------------------------------------------------------------------------------
    mod._browserPanel = mod._bmMan.addPanel({
        priority    = 1,
        id          = "browser",
        label       = i18n("browser"),
        image       = image.imageFromPath(tools.iconFallback(fcpPath .. "/Contents/Frameworks/Flexo.framework/Versions/A/Resources/FFMediaManagerClipIcon.png")),
        tooltip     = i18n("browser"),
        height      = 650,
    })

        :addContent(nextID(), ui.style([[

        ]]))
        :addHeading(nextID(), "Batch Export from Browser")
        :addParagraph(nextID(), function()
                local clipCount = mod._clips and #mod._clips or 0
                local clipCountString = clipsToCountString(mod._clips)
                local itemString = i18n("item", {count=clipCount})
                return "Final Cut Pro will export the " ..  clipCountString .. "selected " ..  itemString .. " in the browser to the following location:"
            end)
        :addParagraph(nextID(), html.br())
        :addContent(nextID(), function()
                local destinationFolder = mod.getDestinationFolder()
                if destinationFolder then
                    return [[<div style="white-space: nowrap; overflow: hidden;"><p class="uiItem" style="color:#5760e7; font-weight:bold;">]] .. destinationFolder .."</p></div>"
                else
                    return [[<p class="uiItem" style="color:#d1393e; font-weight:bold;">No Destination Folder Selected</p>]]
                end
            end, false)
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("changeDestinationFolder"),
                onclick = mod.changeExportDestinationFolder,
            })
        :addParagraph(nextID(), html.br())
        :addParagraph(nextID(), "Using the following Destination Preset:")
        :addParagraph(nextID(), html.br())
        :addContent(nextID(), function()
                local destinationPreset = mod.getDestinationPreset()
                if destinationPreset then
                    return [[<div style="white-space: nowrap; overflow: hidden;"><p class="uiItem" style="color:#5760e7; font-weight:bold;">]] .. mod.getDestinationPreset() .."</p></div>"
                else
                    return [[<p class="uiItem" style="color:#d1393e; font-weight:bold;">No Destination Preset Selected</p>]]
                end
            end, false)
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("changeDestinationPreset"),
                onclick = mod.changeExportDestinationPreset,
            })
        :addParagraph(nextID(), html.br())
        :addParagraph(nextID(), "Using the following naming convention:")
        :addParagraph(nextID(), html.br())
        :addContent(nextID(), function()
                local useCustomFilename = mod.useCustomFilename()
                if useCustomFilename then
                    local customFilename = mod.customFilename() or mod.DEFAULT_CUSTOM_FILENAME
                    return [[<div style="white-space: nowrap; overflow: hidden;"><p class="uiItem" style="color:#5760e7; font-weight:bold;">]] .. customFilename .."</p></div>"
                else
                    return [[<p class="uiItem" style="color:#3f9253; font-weight:bold;">Original Clip/Project Name</p>]]
                end
            end, false)
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("changeCustomFilename"),
                onclick = mod.changeCustomFilename,
            })
        :addHeading(nextID(), "Preferences")
        :addCheckbox(nextID(),
            {
                label = i18n("replaceExistingFiles"),
                onchange = function(_, params) mod.replaceExistingFiles(params.checked) end,
                checked = mod.replaceExistingFiles,
            })
        :addCheckbox(nextID(),
            {
                label = i18n("ignoreMissingEffects"),
                onchange = function(_, params) mod.ignoreMissingEffects(params.checked) end,
                checked = mod.ignoreMissingEffects,
            })
        :addCheckbox(nextID(),
            {
                label = i18n("ignoreProxies"),
                onchange = function(_, params) mod.ignoreProxies(params.checked) end,
                checked = mod.ignoreProxies,
            })
        :addCheckbox(nextID(),
            {
                label = i18n("useCustomFilename"),
                onchange = function(_, params)
                    mod.useCustomFilename(params.checked)

                    --------------------------------------------------------------------------------
                    -- Refresh the Preferences:
                    --------------------------------------------------------------------------------
                    mod._bmMan.refresh()
                end,
                checked = mod.useCustomFilename,
            })
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("performBatchExport"),
                onclick = function() mod.performBatchExport("browser") end,
            })

    --------------------------------------------------------------------------------
    -- Timeline Panel:
    --------------------------------------------------------------------------------
    mod._timelinePanel = mod._bmMan.addPanel({
        priority    = 2,
        id          = "timeline",
        label       = i18n("timeline"),
        image       = image.imageFromPath(tools.iconFallback(fcpPath .. "/Contents/Frameworks/Flexo.framework/Versions/A/Resources/FFMediaManagerCompoundClipIcon.png")),
        tooltip     = i18n("timeline"),
        height      = 650,
    })
        :addHeading(nextID(), "Batch Export from Timeline")
        :addParagraph(nextID(), function()
                local clipCount = mod._clips and #mod._clips or 0
                local clipCountString = clipsToCountString(mod._clips)
                local itemString = i18n("item", {count=clipCount})
                return "Final Cut Pro will export the " ..  clipCountString .. "selected " ..  itemString .. " in the timeline to the following location:"
            end)
        :addParagraph(nextID(), html.br())
        :addContent(nextID(), function()
                local destinationFolder = mod.getDestinationFolder()
                if destinationFolder then
                    return [[<div style="white-space: nowrap; overflow: hidden;"><p class="uiItem" style="color:#5760e7; font-weight:bold;">]] .. destinationFolder .."</p></div>"
                else
                    return [[<p class="uiItem" style="color:#d1393e; font-weight:bold;">No Destination Folder Selected</p>]]
                end
            end, false)
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("changeDestinationFolder"),
                onclick = mod.changeExportDestinationFolder,
            })
        :addParagraph(nextID(), html.br())
        :addParagraph(nextID(), "Using the following Destination Preset:")
        :addParagraph(nextID(), html.br())
        :addContent(nextID(), function()
                local destinationPreset = mod.getDestinationPreset()
                if destinationPreset then
                    return [[<div style="white-space: nowrap; overflow: hidden;"><p class="uiItem" style="color:#5760e7; font-weight:bold;">]] .. mod.getDestinationPreset() .."</p></div>"
                else
                    return [[<p class="uiItem" style="color:#d1393e; font-weight:bold;">No Destination Preset Selected</p>]]
                end
            end, false)
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("changeDestinationPreset"),
                onclick = mod.changeExportDestinationPreset,
            })
        :addParagraph(nextID(), html.br())
        :addParagraph(nextID(), "Using the following naming convention:")
        :addParagraph(nextID(), html.br())
        :addContent(nextID(), function()
                local useCustomFilename = mod.useCustomFilename()
                if useCustomFilename then
                    local customFilename = mod.customFilename() or mod.DEFAULT_CUSTOM_FILENAME
                    return [[<div style="white-space: nowrap; overflow: hidden;"><p class="uiItem" style="color:#5760e7; font-weight:bold;">]] .. customFilename .."</p></div>"
                else
                    return [[<p class="uiItem" style="color:#3f9253; font-weight:bold;">Original Clip Name</p>]]
                end
            end, false)
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("changeCustomFilename"),
                onclick = mod.changeCustomFilename,
            })
        :addHeading(nextID(), "Preferences")
        :addCheckbox(nextID(),
            {
                label = i18n("replaceExistingFiles"),
                onchange = function(_, params) mod.replaceExistingFiles(params.checked) end,
                checked = mod.replaceExistingFiles,
            })
        :addCheckbox(nextID(),
            {
                label = i18n("ignoreMissingEffects"),
                onchange = function(_, params) mod.ignoreMissingEffects(params.checked) end,
                checked = mod.ignoreMissingEffects,
            })
        :addCheckbox(nextID(),
            {
                label = i18n("ignoreProxies"),
                onchange = function(_, params) mod.ignoreProxies(params.checked) end,
                checked = mod.ignoreProxies,
            })
        :addCheckbox(nextID(),
            {
                label = i18n("useCustomFilename"),
                onchange = function(_, params)
                    mod.useCustomFilename(params.checked)

                    --------------------------------------------------------------------------------
                    -- Refresh the Preferences:
                    --------------------------------------------------------------------------------
                    mod._bmMan.refresh()
                end,
                checked = mod.useCustomFilename,
            })
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("performBatchExport"),
                onclick = function() mod.performBatchExport("timeline") end,
            })

    --------------------------------------------------------------------------------
    -- Add items to Menubar:
    --------------------------------------------------------------------------------
    local section = deps.prefs:addSection(PRIORITY)
    local menu = section:addMenu(1000, function() return i18n("batchExport") end)
    menu:addItems(1, function()
        return {
            {
                title       = i18n("browser"),
                fn          = function() mod.batchExport("browser") end,
                disabled    = not fcp:isRunning()
            },
            {
                title       = i18n("timeline"),
                fn          = function() mod.batchExport("timeline") end,
                disabled    = not fcp:isRunning()
            },
        }
    end)

    --------------------------------------------------------------------------------
    -- Commands:
    --------------------------------------------------------------------------------
    deps.fcpxCmds:add("cpBatchExport")
        :activatedBy():ctrl():option():cmd("e")
        :whenActivated(mod.batchExport)

    deps.fcpxCmds:add("cpBatchExportFromBrowser")
        :whenActivated(function() mod.batchExport("browser") end)

    deps.fcpxCmds:add("cpBatchExportFromTimeline")
        :whenActivated(function() mod.batchExport("timeline") end)

    --------------------------------------------------------------------------------
    -- Return the module:
    --------------------------------------------------------------------------------
    return mod
end

return plugin
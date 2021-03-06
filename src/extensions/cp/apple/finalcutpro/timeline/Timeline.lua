--- === cp.apple.finalcutpro.timeline.Timeline ===
---
--- Timeline Module.

local require = require

--local log								= require "hs.logger".new "timeline"

local axutils							= require "cp.ui.axutils"
local Element                           = require "cp.ui.Element"
local go                                = require "cp.rx.go"
local prop								= require "cp.prop"
local tools                             = require "cp.tools"

local Contents					        = require "cp.apple.finalcutpro.timeline.Contents"
local EffectsBrowser					= require "cp.apple.finalcutpro.main.EffectsBrowser"
local Index                             = require "cp.apple.finalcutpro.timeline.Index"
local PrimaryWindow						= require "cp.apple.finalcutpro.main.PrimaryWindow"
local SecondaryWindow					= require "cp.apple.finalcutpro.main.SecondaryWindow"
local SpeedPopover                      = require "cp.apple.finalcutpro.timeline.SpeedPopover"
local Toolbar					        = require "cp.apple.finalcutpro.timeline.Toolbar"

local cache                             = axutils.cache
local childMatching                     = axutils.childMatching
local childrenWithRole                  = axutils.childrenWithRole
local childWithRole                     = axutils.childWithRole

local Do                                = go.Do
local If                                = go.If
local WaitUntil                         = go.WaitUntil

local playErrorSound                    = tools.playErrorSound

local Timeline = Element:subclass("cp.apple.finalcutpro.timeline.Timeline")

--- cp.apple.finalcutpro.timeline.Timeline.matches(element) -> boolean
--- Function
--- Checks to see if an element matches what we think it should be.
---
--- Parameters:
---  * element - An `axuielementObject` to check.
---
--- Returns:
---  * `true` if matches otherwise `false`.
---
--- Notes:
---  * `element` should be an `AXGroup`, which contains an `AXSplitGroup` with an
---    `AXIdentifier` of `_NS:237` (as of Final Cut Pro 10.4)
function Timeline.static.matches(element)
    local splitGroup = childWithRole(element, "AXSplitGroup")
    return element:attributeValue("AXRole") == "AXGroup"
       and splitGroup
       and Timeline.matchesMain(splitGroup)
end

--- cp.apple.finalcutpro.timeline.Timeline.matchesMain(element) -> boolean
--- Function
--- Checks to see if an element matches what we think it should be.
---
--- Parameters:
---  * element - An `axuielementObject` to check.
---
--- Returns:
---  * `true` if matches otherwise `false`
---
--- Notes:
---  * `element` should be an `AXSplitGroup` with an `AXIdentifier` of `_NS:237`
---    (as of Final Cut Pro 10.4)
---  * Because the timeline contents is hard to detect, we look for the timeline
---    toolbar instead.
function Timeline.static.matchesMain(element)
    local parent = element and element:attributeValue("AXParent")
    local group = parent and childWithRole(parent, "AXGroup")
    local buttons = group and childrenWithRole(group, "AXButton")
    return buttons and #buttons >= 6
end

-- _findTimeline(...) -> window | nil
-- Function
-- Gets the Timeline UI.
--
-- Parameters:
--  * ... - Table of elements.
--
-- Returns:
--  * An `axuielementObject` or `nil`
function Timeline.static._findTimeline(...)
    for i = 1,select("#", ...) do
        local window = select(i, ...)
        if window then
            local ui = window:timelineGroupUI()
            if ui then
                local timeline = childMatching(ui, Timeline.matches)
                if timeline then return timeline end
            end
        end
    end
    return nil
end

--- cp.apple.finalcutpro.timeline.Timeline(app) -> Timeline
--- Constructor
--- Creates a new `Timeline` instance.
---
--- Parameters:
---  * app - The `cp.apple.finalcutpro` object.
---
--- Returns:
---  * A new `Timeline` object.
function Timeline:initialize(app)

    local UI = app.UI:mutate(function()
        return cache(self, "_ui", function()
            return Timeline._findTimeline(app:secondaryWindow(), app:primaryWindow())
        end,
        Timeline.matches)
    end):monitor(app:primaryWindow().UI, app:secondaryWindow().UI)

    Element.initialize(self, app, UI)
end

--- cp.apple.finalcutpro.timeline.Timeline.isOnSecondary <cp.prop: boolean; read-only>
--- Field
--- Checks if the Timeline is on the Secondary Display.
function Timeline.lazy.prop:isOnSecondary()
    return self.UI:mutate(function(original)
        local ui = original()
        return ui ~= nil and SecondaryWindow.matches(ui:window())
    end)
end

--- cp.apple.finalcutpro.timeline.Timeline.isOnPrimary <cp.prop: boolean; read-only>
--- Field
--- Checks if the Timeline is on the Primary Display.
function Timeline.lazy.prop:isOnPrimary()
    return self.UI:mutate(function(original)
        local ui = original()
        return ui ~= nil and PrimaryWindow.matches(ui:window())
    end)
end

--- cp.apple.finalcutpro.timeline.Timeline.isShowing <cp.prop: boolean; read-only>
--- Field
--- Checks if the Timeline is showing on either the Primary or Secondary display.
function Timeline.lazy.prop:isShowing()
    return self.UI:mutate(function(original)
        local ui = original()
        return ui ~= nil and #ui > 0
    end)
end

--- cp.apple.finalcutpro.timeline.Timeline.mainUI <cp.prop: hs._asm.axuielement; read-only>
--- Field
--- Returns the `axuielement` representing the 'timeline', or `nil` if not available.
function Timeline.lazy.prop:mainUI()
    return self.UI:mutate(function(original)
        return cache(self, "_main", function()
            local ui = original()
            return ui and childMatching(ui, Timeline.matchesMain)
        end,
        Timeline.matchesMain)
    end)
end

--- cp.apple.finalcutpro.timeline.Timeline.isPlaying <cp.prop: boolean>
--- Field
--- Is the timeline playing?
function Timeline.lazy.prop:isPlaying()
    return self:app():viewer().isPlaying
end

--- cp.apple.finalcutpro.timeline.Timeline.isLockedPlayhead <cp.prop: boolean>
--- Field
--- Is Playhead Locked?
function Timeline.lazy.prop.isLockedPlayhead()
    return prop.TRUE()
end

--- cp.apple.finalcutpro.timeline.Timeline.isLockedInCentre <cp.prop: boolean>
--- Field
--- Is Playhead Locked in the centre?
function Timeline.lazy.prop.isLockedInCentre()
    return prop.TRUE()
end

--- cp.apple.finalcutpro.timeline.Timeline.isLoaded <cp.prop: boolean; read-only>
--- Field
--- Checks if the Timeline has finished loading.
function Timeline.lazy.prop:isLoaded()
    return self:contents().isLoaded
end

--- cp.apple.finalcutpro.timeline.Timeline.isFocused <cp.prop: boolean; read-only>
--- Field
--- Checks if the Timeline is the focused panel.
function Timeline.lazy.prop:isFocused()
    return self:contents().isFocused
end

--- cp.apple.finalcutpro.timeline.Timeline:doFocus() -> cp.rx.Statement
--- Method
--- A [Statement](cp.rx.go.Statement.md) that will attempt to focus on the Timeline.
function Timeline.lazy.method:doFocus()
    return self:app():menu():doSelectMenu({"Window", "Go To", "Timeline"})
end

--- cp.apple.finalcutpro.timeline.Timeline:app() -> App
--- Method
--- Returns the app instance representing Final Cut Pro.
---
--- Parameters:
---  * None
---
--- Returns:
---  * App
function Timeline:app()
    return self:parent()
end

-----------------------------------------------------------------------
--
-- TIMELINE UI:
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.timeline.Timeline:show() -> Timeline
--- Method
--- Show's the Timeline on the Primary Display.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Timeline` object.
function Timeline:show()
    if not self:isShowing() then
        self:showOnPrimary()
    end
    return self
end

function Timeline.lazy.method:doShow()
    return If(self.isShowing):Is(false)
    :Then(self:doShowOnPrimary())
    :Otherwise(true)
    :Label("Timeline:doShow")
end

--- cp.apple.finalcutpro.timeline.Timeline:showOnPrimary() -> Timeline
--- Method
--- Show's the Timeline on the Primary Display.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Timeline` object.
function Timeline:showOnPrimary()
    local menu = self:app():menu()

    -- if the timeline is on the secondary, we need to turn it off before enabling in primary
    if self:isOnSecondary() then
        menu:selectMenu({"Window", "Show in Secondary Display", "Timeline"})
    end
    -- Then enable it in the primary
    if not self:isOnPrimary() then
        menu:selectMenu({"Window", "Show in Workspace", "Timeline"})
    end

    return self
end

--- cp.apple.finalcutpro.timeline.Timeline:doShowOnPrimary() -> cp.rx.go.Statement <boolean>
--- Method
--- Returns a `Statement` that will ensure the timeline is in the primary window.
---
--- Parameters:
---  * timeout  - The timeout period for the operation.
---
--- Returns:
---  * A `Statement` which will send `true` if it successful, or `false` otherwise.
function Timeline.lazy.method:doShowOnPrimary()
    local menu = self:app():menu()

    return If(self:app().isRunning):Then(
        Do(
            If(self.isOnSecondary):Then(
                menu:doSelectMenu({"Window", "Show in Secondary Display", "Timeline"})
            )
        )
        :Then(
            If(self.isOnPrimary):Is(false):Then(
                Do(menu:doSelectMenu({"Window", "Show in Workspace", "Timeline"}))
                :Then(WaitUntil(self.isOnPrimary):TimeoutAfter(5000))
            ):Otherwise(true)
        )
    ):Otherwise(false)
    :Label("Timeline:doShowOnPrimary")
end

--- cp.apple.finalcutpro.timeline.Timeline:showOnSecondary() -> Timeline
--- Method
--- Show's the Timeline on the Secondary Display.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Timeline` object.
function Timeline:showOnSecondary()
    local menu = self:app():menu()

    -- if the timeline is on the secondary, we need to turn it off before enabling in primary
    if not self:isOnSecondary() then
        menu:selectMenu({"Window", "Show in Secondary Display", "Timeline"})
    end

    return self
end

--- cp.apple.finalcutpro.timeline.Timeline:doShowOnSecondary() -> cp.rx.go.Statement <boolean>
--- Method
--- Returns a `Statement` that will ensure the timeline is in the secondary window.
---
--- Parameters:
---  * timeout  - The timeout period for the operation.
---
--- Returns:
---  * A `Statement` which will send `true` if it successful, or `false` otherwise.
function Timeline.lazy.method:doShowOnSecondary()
    local menu = self:app():menu()

    return If(self:app().isRunning):Then(
        If(self.isOnSecondary):Is(false)
        :Then(menu:doSelectMenu({"Window", "Show in Secondary Display", "Timeline"}))
        :Then(WaitUntil(self.isOnSecondary):TimeoutAfter(5000))
        :Otherwise(true)
    ):Otherwise(false)
    :Label("Timeline:doShowOnSecondary")
end

--- cp.apple.finalcutpro.timeline.Timeline:hide() -> Timeline
--- Method
--- Hide's the Timeline (regardless of whether it was on the Primary or Secondary display).
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Timeline` object.
function Timeline:hide()
    local menu = self:app():menu()
    -- Uncheck it from the primary workspace
    if self:isOnSecondary() then
        menu:selectMenu({"Window", "Show in Secondary Display", "Timeline"})
    end
    if self:isOnPrimary() then
        menu:selectMenu({"Window", "Show in Workspace", "Timeline"})
    end
    return self
end

--- cp.apple.finalcutpro.timeline.Timeline:doHide() -> cp.rx.go.Statement
--- Method
--- Returns a `Statement` that will hide the Timeline (regardless of whether it
--- was on the Primary or Secondary window).
---
--- Parameters:
---  * None
---
--- Returns:
---  * A `Statement` ready to run.
function Timeline.lazy.method:doHide()
    local menu = self:app():menu()

    return If(self:app().isRunning):Then(
        Do(
            If(self.isOnSecondary):Then(
                menu:doSelectMenu({"Window", "Show in Secondary Display", "Timeline"})
            )
            :Then(WaitUntil(self.isOnSecondary:NOT()):TimeoutAfter(5000))
        )
        :Then(
            If(self.isOnPrimary):Then(
                menu:doSelectMenu({"Window", "Show in Workspace", "Timeline"})
            )
            :Then(WaitUntil(self.isOnPrimary:NOT()):TimeoutAfter(5000))
            :Otherwise(true)
        )
    ):Otherwise(false)
    :Label("Timeline:doHide")
end

--- cp.apple.finalcutpro.timeline.Contents:doFocus(show) -> cp.rx.go.Statement
--- Method
--- A [Statement](cp.rx.go.Statement.md) which will focus on the `Contents`.
---
--- Parameters:
--- * show      - if `true`, the `Contents` will be shown before focusing.
---
--- Returns:
--- * The `Statement`.
function Timeline:doFocus(show)
    return self:contents():doFocus(show)
    :Label("Timeline:doFocus")
end

-----------------------------------------------------------------------
--
-- CONTENTS:
-- The Contents is the main body of the timeline, containing the
-- Timeline Index, the Contents, and the Effects/Transitions panels.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.timeline.Timeline:contents() -> TimelineContent
--- Method
--- Gets the Timeline Contents. The Content is the main body of the timeline,
--- containing the Timeline Index, the Content, and the Effects/Transitions panels.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `TimelineContent` object.
function Timeline.lazy.method:contents()
    return Contents.new(self)
end

-----------------------------------------------------------------------
--
-- EFFECTS BROWSER:
-- The (sometimes hidden) Effects Browser.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.timeline.Timeline:effects() -> EffectsBrowser
--- Method
--- Gets the (sometimes hidden) Effect Browser.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `EffectsBrowser` object.
function Timeline.lazy.method:effects()
    return EffectsBrowser.new(self, EffectsBrowser.EFFECTS)
end

-----------------------------------------------------------------------
--
-- TRANSITIONS BROWSER:
-- The (sometimes hidden) Transitions Browser.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.timeline.Timeline:transitions() -> EffectsBrowser
--- Method
--- Gets the (sometimes hidden) Transitions Browser.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `EffectsBrowser` object.
function Timeline.lazy.method:transitions()
    return EffectsBrowser.new(self, EffectsBrowser.TRANSITIONS)
end

-----------------------------------------------------------------------
--
-- PLAYHEAD:
-- The timeline Playhead.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.timeline.Timeline:playhead() -> Playhead
--- Method
--- Gets the Timeline Playhead.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Playhead` object.
function Timeline:playhead()
    return self:contents():playhead()
end

-----------------------------------------------------------------------
--
-- SKIMMING PLAYHEAD:
-- The Playhead that tracks under the mouse while skimming.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.timeline.Timeline:skimmingPlayhead() -> Playhead
--- Method
--- Gets the Playhead that tracks under the mouse while skimming.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Playhead` object.
function Timeline:skimmingPlayhead()
    return self:contents():skimmingPlayhead()
end

-----------------------------------------------------------------------
--
-- TOOLBAR:
-- The bar at the top of the timeline.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.timeline.Timeline:toolbar() -> Toolbar
--- Method
--- Gets the bar at the top of the timeline.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Toolbar` object.
function Timeline.lazy.method:toolbar()
    return Toolbar(self)
end

--- cp.apple.finalcutpro.timeline.Timeline:title() -> cp.ui.StaticText
--- Method
--- Returns the [StaticText](cp.ui.StaticText.md) containing the title.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `StaticText` object.
function Timeline:title()
    return self:toolbar():title()
end

--- cp.apple.finalcutpro.timeline.Timeline.rangeSelected <cp.prop: boolean; read-only>
--- Field
--- Checks if a range is selected in the timeline.
function Timeline.lazy.prop:rangeSelected()
    return self:toolbar():duration().UI:mutate(function(original)
        local ui = original()
        local value = ui and ui:attributeValue("AXValue")
        return value and (value:find("/") ~= nil or value:find("／") ~= nil)
    end)
end

-----------------------------------------------------------------------
--
-- INDEX:
-- The Timeline Index.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.timeline.Timeline:index() -> Index
--- Method
--- The [Index](cp.apple.finalcutpro.timeline.Index.md).
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Index` object.
function Timeline.lazy.method:index()
    return Index(self)
end

-----------------------------------------------------------------------
--
-- TIMELINE NAVIGATION:
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.timeline.Timeline:openProject(title) -> none
--- Method
--- Opens a project from the timeline navigation popups.
---
--- Parameters:
---  * title - The title of the project you want to open.
---
--- Returns:
---  * None
---
--- Notes:
---  * The title supports patterns, so you can do things like:
---    `require("cp.apple.finalcutpro"):timeline():openProject("Audio.*")`
function Timeline:openProject(title)
    local backButton = self:toolbar():back():UI()
    local forwardButton = self:toolbar():forward():UI()
    if backButton and backButton:attributeValue("AXEnabled") then
        backButton:performAction("AXShowMenu")
        local menu = childWithRole(backButton, "AXMenu")
        if menu then
            local children = menu:attributeValue("AXChildren")
            for _, item in pairs(children) do
                if string.match(item:attributeValue("AXTitle"), title) then
                    item:performAction("AXPress")
                    return
                end
            end
        end
        menu:performAction("AXCancel")
    end
    if forwardButton and forwardButton:attributeValue("AXEnabled") then
        forwardButton:performAction("AXShowMenu")
        local menu = childWithRole(forwardButton, "AXMenu")
        if menu then
            local children = menu:attributeValue("AXChildren")
            for _, item in pairs(children) do
                if string.match(item:attributeValue("AXTitle"), title) then
                    item:performAction("AXPress")
                    return
                end
            end
        end
        menu:performAction("AXCancel")
    end
    playErrorSound()
end

-----------------------------------------------------------------------
--
-- SPEED POPOVER:
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.timeline.Timeline.speedPopover <cp.apple.finalcutpro.timeline.SpeedPopover>
--- Field
--- Provides the [SpeedPopover](cp.apple.finalcutpro.timeline.SpeedPopover.md).
function Timeline.lazy.value:speedPopover()
    return SpeedPopover(self)
end

return Timeline

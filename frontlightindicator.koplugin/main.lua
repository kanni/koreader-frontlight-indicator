--[[--
Front light indicator.

Shows a small symbol in the reader status bar (footer) — and optionally the top
status bar (header) — while the front light is on, and nothing at all when it is off.
Uses the supported ReaderFooter / ReaderCoptListener external-content APIs, so no core
files are patched.

@module koplugin.FrontLightIndicator
--]]--

local Device = require("device")

-- Nothing to indicate on devices without a front light.
if not Device:hasFrontlight() then
    return { disabled = true }
end

local Event = require("ui/event")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

-- In "auto" mode the symbol follows the footer's chosen prefix style
-- (Status bar > item style), mirroring the stock "frontlight" item's symbols.
local AUTO_SYMBOL = {
    icons = "☼",
    compact_items = "✺",
    letters = "L",
}

-- Symbol picker options, in menu order. value "auto" -> AUTO_SYMBOL above;
-- any other value is used verbatim as the indicator glyph.
local EMOJI_HELP = _([[Note: this is an emoji glyph. It renders in the emulator, but on some e-ink devices it may appear in black and white or as an empty box, depending on the installed fonts. The sun (☼), star (✺) and letter styles are the safest.]])
local SYMBOL_CHOICES = {
    {
        value = "auto",
        text = _("Automatic (match status bar style)"),
        help = _([[Uses the same symbol as the stock front light item, following your status bar item style (Status bar ▸ Configure items ▸ item style):
• Icons style → ☼
• Compact style → ✺
• Letters style → L

The plain letter "L" appears only when your status bar is set to the Letters style, which uses text abbreviations instead of icons (the stock front light item shows "L:" there too). Pick a specific symbol below to always use that glyph regardless of the status bar style.]]),
    },
    { value = "☼",  text = _("Sun with rays (☼)") },
    { value = "☀",  text = _("Black sun (☀)"), help = EMOJI_HELP },
    { value = "✺",  text = _("Star (✺)") },
    { value = "💡", text = _("Light bulb (💡)"), help = EMOJI_HELP },
}

-- Fast lookup of preset symbol values, to detect a user-entered custom symbol.
local PRESET_VALUES = {}
for _, choice in ipairs(SYMBOL_CHOICES) do
    PRESET_VALUES[choice.value] = true
end

local FrontLightIndicator = WidgetContainer:extend{
    name = "frontlightindicator",
    is_doc_only = true,
}

function FrontLightIndicator:init()
    -- Stable closure references so we can unregister exactly what we added.
    -- Return nil while the light is off -> the generator renders nothing.
    self.footer_content_func = function()
        if Device:getPowerDevice():isFrontlightOn() then
            return self:getSymbol()
        end
    end
    self.header_content_func = function()
        if Device:getPowerDevice():isFrontlightOn() then
            return self:getSymbol()
        end
    end

    self.enabled = G_reader_settings:nilOrTrue("frontlight_indicator_enabled")
    self.header_enabled = G_reader_settings:isTrue("frontlight_indicator_header_enabled")
    self.symbol = G_reader_settings:readSetting("frontlight_indicator_symbol", "auto")

    if self.enabled then
        self:register()
    end
    if self.header_enabled then
        self:registerHeader()
    end

    self.ui.menu:registerToMainMenu(self)
end

-- Resolve the glyph to show, honoring the user's picked/custom symbol or the footer style.
function FrontLightIndicator:getSymbol()
    if self.symbol == nil or self.symbol == "auto" then
        local style = self.ui.view.footer.settings.item_prefix
        return AUTO_SYMBOL[style] or AUTO_SYMBOL.icons
    end
    return self.symbol
end

-- True when the user has entered their own symbol/text (not a preset, not auto).
function FrontLightIndicator:isCustom()
    return self.symbol ~= nil and not PRESET_VALUES[self.symbol]
end

-- The top status bar (header) does not react to front light changes on its own, so
-- refresh it here. The footer refreshes itself on FrontlightStateChanged.
function FrontLightIndicator:onFrontlightStateChanged()
    if self.header_enabled then
        UIManager:broadcastEvent(Event:new("UpdateHeader"))
    end
end

-- Redraw whichever bars are showing the indicator (e.g. after a symbol change).
function FrontLightIndicator:notifyChanged()
    if self.enabled then
        UIManager:broadcastEvent(Event:new("UpdateFooter", true))
    end
    if self.header_enabled then
        UIManager:broadcastEvent(Event:new("UpdateHeader"))
    end
end

function FrontLightIndicator:register()
    if self.ui.view then
        self.ui.view.footer:addAdditionalFooterContent(self.footer_content_func)
        UIManager:broadcastEvent(Event:new("UpdateFooter", true))
    end
end

function FrontLightIndicator:unregister()
    if self.ui.view then
        self.ui.view.footer:removeAdditionalFooterContent(self.footer_content_func)
        UIManager:broadcastEvent(Event:new("UpdateFooter", true))
    end
end

-- The header (top status bar) only exists for reflowable documents (crelistener).
function FrontLightIndicator:registerHeader()
    if self.ui.crelistener then
        self.ui.crelistener:addAdditionalHeaderContent(self.header_content_func)
        UIManager:broadcastEvent(Event:new("UpdateHeader"))
    end
end

function FrontLightIndicator:unregisterHeader()
    if self.ui.crelistener then
        self.ui.crelistener:removeAdditionalHeaderContent(self.header_content_func)
        UIManager:broadcastEvent(Event:new("UpdateHeader"))
    end
end

function FrontLightIndicator:editCustomSymbol(touchmenu_instance)
    local dialog
    dialog = InputDialog:new{
        title = _("Custom indicator symbol"),
        input = self:isCustom() and self.symbol or "",
        input_hint = _("e.g. ☼ or LIGHT"),
        description = _("Text or symbol shown in the status bar while the front light is on."),
        buttons = {{
            {
                text = _("Cancel"),
                id = "close",
                callback = function()
                    UIManager:close(dialog)
                end,
            },
            {
                text = _("Set"),
                is_enter_default = true,
                callback = function()
                    local text = dialog:getInputText()
                    if text and text ~= "" then
                        self.symbol = text
                        G_reader_settings:saveSetting("frontlight_indicator_symbol", self.symbol)
                        self:notifyChanged()
                    end
                    UIManager:close(dialog)
                    if touchmenu_instance then touchmenu_instance:updateItems() end
                end,
            },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function FrontLightIndicator:addToMainMenu(menu_items)
    local symbol_items = {}
    for i, choice in ipairs(SYMBOL_CHOICES) do
        symbol_items[i] = {
            text = choice.text,
            help_text = choice.help,
            radio = true,
            checked_func = function()
                return self.symbol == choice.value
            end,
            callback = function()
                self.symbol = choice.value
                G_reader_settings:saveSetting("frontlight_indicator_symbol", self.symbol)
                self:notifyChanged()
            end,
        }
    end
    -- Custom text/symbol entry (opens an input dialog).
    table.insert(symbol_items, {
        text_func = function()
            if self:isCustom() then
                return T(_("Custom: %1"), self.symbol)
            end
            return _("Custom…")
        end,
        help_text = _([[Enter any text or symbol to use as the indicator (for example a single glyph, or a short word like "LIGHT"). It is shown as-is while the front light is on.]]),
        radio = true,
        checked_func = function()
            return self:isCustom()
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            self:editCustomSymbol(touchmenu_instance)
        end,
    })

    menu_items.frontlight_indicator = {
        text = _("Front light indicator"),
        sorting_hint = "device",
        help_text = _([[Shows a small symbol in the status bar while the front light is on, and nothing at all while it is off — an at-a-glance reminder that the light is on.]]),
        sub_item_table = {
            {
                text = _("Show in bottom status bar"),
                help_text = _([[Shows the indicator in the bottom status bar (footer), added as "External content". The symbol only appears while the front light is on; when the light is off, nothing is shown and no space is used.]]),
                checked_func = function()
                    return self.enabled
                end,
                callback = function()
                    self.enabled = not self.enabled
                    G_reader_settings:saveSetting("frontlight_indicator_enabled", self.enabled)
                    if self.enabled then
                        self:register()
                    else
                        self:unregister()
                    end
                end,
            },
            {
                text = _("Show in top status bar"),
                help_text = _([[Shows the indicator in the top status bar (header). The top status bar is only available for reflowable documents such as EPUB; it does not exist for PDFs, so this option has no effect there.]]),
                enabled_func = function()
                    return self.ui.crelistener ~= nil
                end,
                checked_func = function()
                    return self.header_enabled
                end,
                callback = function()
                    self.header_enabled = not self.header_enabled
                    G_reader_settings:saveSetting("frontlight_indicator_header_enabled", self.header_enabled)
                    if self.header_enabled then
                        self:registerHeader()
                    else
                        self:unregisterHeader()
                    end
                end,
                separator = true,
            },
            {
                text_func = function()
                    -- show the currently active glyph next to the "Symbol" heading
                    return T(_("Symbol: %1"), self:getSymbol())
                end,
                help_text = _([[Choose which symbol marks that the front light is on. "Automatic" follows your status bar item style; any other choice always uses that specific glyph. Long-press an option for details.]]),
                sub_item_table = symbol_items,
            },
        },
    }
end

return FrontLightIndicator

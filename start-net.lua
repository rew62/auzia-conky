----------------------------------
-- Standalone network widget
-- Extracted from Auzia Conky
----------------------------------

require("cairo")
require("imlib2")

-- ── Settings ──────────────────────────────────────────────────────────────────

THEME = "blue dark"

startup_delay = 5

--[[
Edit to match your network interface.
Find it with `ifconfig` or `ip link` — e.g. "wlan0", "eth0", "wlp3s0".
]]
local function _read_env_interface(path)
    local f = io.open(path, "r")
    if not f then return nil end
    for line in f:lines() do
        local v = line:match('^INTERFACE_NAME%s*=%s*"?([^"\']*)"?')
        if v and v ~= "" then f:close(); return v end
    end
    f:close()
    return nil
end
net_interface = _read_env_interface("../alien/.env") or "wlp2s0"

download_rate_maximum = 1000    -- kb
upload_rate_maximum   = 1000    -- kb

main_font  = "Rubik"
glyph_font = "MonaspiceNe Nerd Font"

--[[
WARNING: fetches your public IP from a third-party service.
Set to true only if you accept the privacy implications.
]]
use_public_ip         = false
public_ip_refresh_rate = 60     -- seconds

-- ── Colors ────────────────────────────────────────────────────────────────────

local function build_color(bg, fg, text, warn, critic, bg_alpha, fg_alpha)
    return {
        bg       = bg,
        fg       = fg,
        text     = text,
        warn     = warn     or 0xFF9000,
        critic   = critic   or 0xFF0000,
        bg_alpha = bg_alpha or 0.2,
        fg_alpha = fg_alpha or 0.8,
    }
end

local dark_text_color  = 0xD1CDD5
local light_text_color = 0x1D1D1D

local _color_table = {
    blue_dark        = build_color(0xA6A6A6, 0x5594FF, dark_text_color),
    blue_light       = build_color(0x252525, 0x151515, light_text_color),
    deepblue_dark    = build_color(0xA6A6A6, 0x0000a8, 0x55ffff, nil, nil, 0.1),
    deepblue_light   = build_color(0x180047, 0x00008B, 0x180047, nil, nil, 0.1),
    green_dark       = build_color(0xA6A6A6, 0x00ff00, dark_text_color),
    green_light      = build_color(0x252525, 0x00ff00, light_text_color),
    emerald_dark     = build_color(0xD3FACD, 0x539950, 0xD3FACD, nil, nil, 0.1),
    emerald_light    = build_color(0x8bff85, 0x3f753d, 0x1a3019, nil, nil, 0.1),
    yellow_dark      = build_color(0xA6A6A6, 0xfafa37, dark_text_color),
    yellow_light     = build_color(0x252525, 0xfdff00, light_text_color),
    purple_dark      = build_color(0xA6A6A6, 0xbc00bc, dark_text_color),
    purple_light     = build_color(0x252525, 0x800080, light_text_color),
    violet_dark      = build_color(0xA6A6A6, 0x7028E5, dark_text_color),
    violet_light     = build_color(0x252525, 0x5329AE, light_text_color),
    crimson_dark     = build_color(0xA6A6A6, 0xdc143c, dark_text_color),
    crimson_light    = build_color(0x252525, 0xd11339, light_text_color),
    maroon_dark      = build_color(0xA6A6A6, 0xae0000, dark_text_color),
    maroon_light     = build_color(0x252525, 0x940000, light_text_color),
    pink_dark        = build_color(0xffccdd, 0xff3377, 0xffccdd),
    pink_light       = build_color(0xffccdd, 0xff3377, 0xff0055),
    cyan_dark        = build_color(0xA6A6A6, 0x48FFE7, dark_text_color),
    cyan_light       = build_color(0x252525, 0x00C9AF, light_text_color),
    aquamarine_dark  = build_color(0xA6A6A6, 0x76EDC3, dark_text_color),
    aquamarine_light = build_color(0x252525, 0x64C8A5, light_text_color),
    monochrome_dark  = build_color(0x484848, 0xDEDEDE, 0xDEDEDE, 0xFF0000, 0xDEDEDE),
    monochrome_light = build_color(0x252525, 0x151515, 0x151515, 0xFF0000, 0x1D1D1D),
    gruvbox_dark     = build_color(0x282828, 0xEBDBB2, 0xFBF1C7, 0xFE8019, 0xCC241D),
    gruvbox_light    = build_color(0xFBF1C7, 0x3C3836, 0x282828, 0xD65D0E, 0xCC241D),
    contrast_dark    = build_color(0x000000, 0xffffff, 0xffffff, 0xf36910, 0xFF0000, 0.5, 1),
    contrast_light   = build_color(0xffffff, 0x000000, 0x000000, 0xf36910, 0xFF0000, 0.3, 1),
}

local function get_color_table(theme)
    local key = string.gsub(string.lower(theme), " ", "_")
    local t = _color_table[key]
    if t == nil then
        io.stderr:write("ERROR: theme '" .. key .. "' not found. Defaulting to 'blue_dark'\n")
        return _color_table["blue_dark"]
    end
    return t
end

colors = get_color_table(THEME)

-- ── Network interface parse strings ───────────────────────────────────────────

local _download_speed    = "downspeed "               .. net_interface
local _download_speed_kb = "downspeedf "              .. net_interface
local _download_total    = "totaldown "               .. net_interface
local _upload_speed      = "upspeed "                 .. net_interface
local _upload_speed_kb   = "upspeedf "                .. net_interface
local _upload_total      = "totalup "                 .. net_interface
local _ssid              = "wireless_essid "          .. net_interface
local _wifi_signal       = "wireless_link_qual_perc " .. net_interface
local _local_ip          = "addr "                    .. net_interface

-- ── Helpers ───────────────────────────────────────────────────────────────────

function parse(str)
    return conky_parse(string.format("${%s}", str))
end

function color_convert(colour, alpha)
    return ((colour / 0x10000) % 0x100) / 255.,
           ((colour / 0x100)   % 0x100) / 255.,
           (colour % 0x100) / 255.,
           alpha
end

-- ── Cairo drawing ─────────────────────────────────────────────────────────────

function ring_clockwise(x, y, radius, thickness, angle_begin, angle_end, value_str, max_value, fg_color)
    local value = tonumber(value_str)
    if value > max_value then value = max_value end

    angle_begin = angle_begin * (2 * math.pi / 360) - (math.pi / 2)
    angle_end   = angle_end   * (2 * math.pi / 360) - (math.pi / 2)
    -- log scale: arc moves more at low speeds, compresses at high speeds
    local log_ratio = value <= 0 and 0 or (math.log(1 + value) / math.log(1 + max_value))
    local progress  = log_ratio * (angle_end - angle_begin)

    cairo_set_line_width(cr, thickness)
    cairo_set_source_rgba(cr, color_convert(colors.bg, colors.bg_alpha))
    cairo_arc(cr, x, y, radius, angle_begin, angle_end)
    cairo_stroke(cr)

    cairo_set_line_width(cr, thickness)
    cairo_set_source_rgba(cr, color_convert(fg_color, colors.fg_alpha))
    cairo_arc(cr, x, y, radius, angle_begin, angle_begin + progress)
    cairo_stroke(cr)
end

function write(x, y, text, font_size, color, font_name, font_slant, font_face, alpha)
    font_name  = font_name  or main_font
    alpha      = alpha      or 1
    font_slant = font_slant or CAIRO_FONT_SLANT_NORMAL
    font_face  = font_face  or CAIRO_FONT_WEIGHT_NORMAL

    cairo_select_font_face(cr, font_name, font_slant, font_face)
    cairo_set_font_size(cr, font_size)
    cairo_set_source_rgba(cr, color_convert(color, alpha))
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
    cairo_stroke(cr)
end

function write_line_by_line(x, y, interval, content, color, font_size, bold)
    if bold == nil then bold = false end
    local yy = y
    for i in pairs(content) do
        write(x, yy, content[i], font_size, color)
        yy = yy + interval
    end
end

-- ── Network data functions ────────────────────────────────────────────────────

function updates()           return parse("updates") end
function download_speed()    return parse(_download_speed) end
function download_speed_kb() return parse(_download_speed_kb) end
function download_total()    return parse(_download_total) end
function upload_speed()      return parse(_upload_speed) end
function upload_speed_kb()   return parse(_upload_speed_kb) end
function upload_total()      return parse(_upload_total) end
function ssid()              return parse(_ssid) end
function wifi_signal()       return parse(_wifi_signal) end
function local_ip()          return parse(_local_ip) end

local _public_ip = nil

function get_public_ip() return _public_ip end

function update_public_ip()
    local file = io.popen("curl -s http://ipinfo.io/ip")
    if not file then _public_ip = "No Address"; return end
    local output = file:read("*a")
    file:close()
    if output == nil or output == "" or string.len(output) > 15 then
        _public_ip = "No Address"
    else
        _public_ip = tostring(output)
    end
end

-- ── Layout (coordinates shifted from the original 1240×720 widget) ───────────
-- Original net center was at (360, 500); shifted by (-5, -360) to fit 500×270.

local N = {
    x           = 355,
    y           = 140,
    radius      = 100,
    begin_angle = 0,
    end_angle   = 320,
    indicators = {
        down = {x = 300, y = 45},
        up   = {x = 300, y = 65},
    },
    total = {
        down = {x = 355, y = 145},
        up   = {x = 355, y = 125},
    },
    list = {x = 55, y = 120},
}

-- ── Draw ─────────────────────────────────────────────────────────────────────

function draw_net()
    ring_clockwise(N.x, N.y, N.radius,    15, N.begin_angle, N.end_angle, download_speed_kb(), download_rate_maximum, colors.fg)
    ring_clockwise(N.x, N.y, N.radius-18, 15, N.begin_angle, N.end_angle, upload_speed_kb(),   upload_rate_maximum,   colors.fg)

    write(N.indicators.down.x, N.indicators.down.y, "▼ " .. download_speed(), 12, colors.text, glyph_font)
    write(N.indicators.up.x,   N.indicators.up.y,   "▲ " .. upload_speed(),   12, colors.text, glyph_font)

    write(N.total.down.x - 49, N.y - 14,         "Totals",                12, colors.text)
    write(N.total.down.x,      N.total.down.y,   "▼" .. download_total(), 12, colors.text, glyph_font)
    write(N.total.up.x,        N.total.up.y,     "▲" .. upload_total(),   12, colors.text, glyph_font)

    local inf = {}
    table.insert(inf, "SSID: "          .. string.sub(ssid(), 0, 15))
    table.insert(inf, "Wifi Signal:    " .. wifi_signal() .. "%")
    table.insert(inf, "Local IP:       "  .. local_ip())
    if use_public_ip then
        if get_public_ip() == nil or (tonumber(updates()) % public_ip_refresh_rate) == 0 then
            update_public_ip()
        end
        table.insert(inf, "Public IP:      " .. (get_public_ip() or ""))
    end
    write_line_by_line(N.list.x, N.list.y, 20, inf, colors.text, 12)

    write(323, 185, "Internet", 15, colors.text)
end

-- ── Main ─────────────────────────────────────────────────────────────────────

function conky_main()
    if conky_window == nil then return end
    if colors == nil then
        io.stderr:write("Fatal Error: theme not loaded\n")
        return
    end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                                         conky_window.visual, conky_window.width,
                                         conky_window.height)
    cr = cairo_create(cs)

    draw_net()

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    cr = nil
end

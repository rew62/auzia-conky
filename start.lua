----------------------------------
-- Author:      Zineddine SAIBI
-- Software:    Auzia Conky
-- Type:        Conky Theme
-- Version:     0.4
-- License:     GPL-3.0
-- repository:  https://www.github.com/SZinedine/auzia-conky
----------------------------------
require("abstract")

local S = require("rc/gauge")
local to_draw_titles = true

-- detect logical and physical core counts once at startup
local total_cores = 0
local physical_cores = 0
do
    local f = io.open("/proc/cpuinfo", "r")
    if f then
        for line in f:lines() do
            if line:match("^processor%s*:") then total_cores = total_cores + 1 end
            local n = line:match("^cpu cores%s*:%s*(%d+)")
            if n and physical_cores == 0 then physical_cores = tonumber(n) end
        end
        f:close()
    end
    if total_cores == 0   then total_cores   = 1 end
    if physical_cores == 0 then physical_cores = total_cores end
end

-- clamp cpu_cores down to a valid layout if setting exceeds actual hardware
if cpu_cores > total_cores then
    local valid = {12, 10, 8, 6, 4, 2, 0}
    for _, v in ipairs(valid) do
        if v <= total_cores then cpu_cores = v; break end
    end
end

-- set the appropriate cpu object according to the chosen value for `cpu_cores`
local ncores = nil
if     cpu_cores == 0  then ncores = S.cpu.cores._0cores
elseif cpu_cores == 2  then ncores = S.cpu.cores._2cores
elseif cpu_cores == 4  then ncores = S.cpu.cores._4cores
elseif cpu_cores == 6  then ncores = S.cpu.cores._6cores
elseif cpu_cores == 8  then ncores = S.cpu.cores._8cores
elseif cpu_cores == 10 then ncores = S.cpu.cores._10cores
elseif cpu_cores == 12 then ncores = S.cpu.cores._12cores
else
    print("ERROR. the provided value of cpu_cores is not valid. Defaulting to 4 cores")
    ncores = S.cpu.cores._4cores
end

-- detect real mount points once at startup (max 4, same logic as Mimod get_mounts.sh)
local disk_mounts = {}
do
    local real_fs = "ext[234]|xfs|btrfs|ntfs|vfat|exfat|f2fs|nfs4?|cifs|fuseblk|zfs"
    local f = io.popen("findmnt -rno TARGET,FSTYPE 2>/dev/null | grep -E '" .. real_fs .. "'")
    if f then
        for line in f:lines() do
            local target = line:match("^(%S+)")
            if target and not (
                target:match("^/boot") or target:match("^/snap") or
                target:match("^/proc") or target:match("^/sys")  or
                target:match("^/dev")  or target:match("^/run")
            ) then
                local name = target:match("([^/]+)$") or ""
                if name == "" then name = "root" end
                table.insert(disk_mounts, {path = target, name = name})
                if #disk_mounts >= 4 then break end
            end
        end
        f:close()
    end
    if #disk_mounts == 0 then
        disk_mounts = {{path = "/", name = "root"}}
    end

    table.sort(disk_mounts, function(a, b)
        if a.path == "/"     then return true  end
        if b.path == "/"     then return false end
        if a.path == "/home" then return true  end
        if b.path == "/home" then return false end
        return a.path < b.path
    end)
end

function start()
    draw_cpu()
    draw_memory()
    draw_clock()
    draw_disks()
    -- draw_battery()
    draw_titles()
    draw_net()
end


function draw_single_cpu_core(coreN)
    local val = nil
    if coreN.number >= 0 then val = cpu_percent(coreN.number)
    else val = cpu_temperature()
    end

    ring_anticlockwise(S.cpu.x, S.cpu.y, coreN.radius, coreN.thickness, coreN.begin_angle, coreN.end_angle, val, coreN.max_value, color_frompercent(tonumber(val)))

    if coreN.text ~= nil then
        write(coreN.text.x, coreN.text.y, val .. coreN.text.post_particle, 12, colors.text)
    end
end


function draw_cpu()
    for i in pairs(ncores) do
        draw_single_cpu_core(ncores[i])
    end

    write_list_proccesses_cpu(160, 147, 20, 4, 12, colors.text, mono_font)
end


function draw_memory()
    local memperc = memory_percent()
    local swpperc = swap_percent()
    local usedmem = string.format("Usage: %s / %s (%s%s)", memory(), memory_max(), memperc, "%")

    ring_clockwise(S.mem.x, S.mem.y, S.mem.radius,                    S.mem.thickness,      S.mem.begin_angle,      S.mem.end_angle,      memperc, 100, color_frompercent(tonumber(memperc)))
    ring_clockwise(S.mem.x, S.mem.y, S.mem.radius + S.mem.swap.offset, S.mem.swap.thickness, S.mem.swap.begin_angle, S.mem.swap.end_angle, swpperc, 100, color_frompercent(tonumber(swpperc)))
    write(S.mem.text.indicators.x+10, S.mem.text.indicators.y+4, "ram: " ..memperc .. "%", 12, colors.text)
    write(S.mem.text.indicators.x+3, S.mem.text.indicators.y+22, "swap: " ..swpperc .. "%", 12, colors.text)

    write(S.mem.text.process_title.x, S.mem.text.process_title.y, usedmem, 12, colors.text)
    write_list_proccesses_mem(S.mem.text.processes.x, S.mem.text.processes.y, 20, 5, 12, colors.text, mono_font)
end


function draw_clock()
    local s = time_second()
    local m = time_minute()
    local h = time_hour24()
    local date = string.format("%s, %s %s, %s", time_day_short(), time_month_short(), time_day_number(), time_year())

    ring_clockwise(S.clock.x, S.clock.y, S.clock.radius + S.clock.seconds.offset, S.clock.seconds.thickness, S.clock.seconds.begin_angle, S.clock.seconds.end_angle, s, S.clock.seconds.max, colors.fg)
    ring_clockwise(S.clock.x, S.clock.y, S.clock.radius + S.clock.minutes.offset, S.clock.minutes.thickness, S.clock.minutes.begin_angle, S.clock.minutes.end_angle, m, S.clock.minutes.max, colors.fg)
    ring_clockwise(S.clock.x, S.clock.y, S.clock.radius + S.clock.hours.offset,   S.clock.hours.thickness,   S.clock.hours.begin_angle,   S.clock.hours.end_angle,   h, S.clock.hours.max,   colors.fg)

    write_bold(S.clock.hr.x, S.clock.hr.y, h, S.clock.font_height, colors.text)
    write(S.clock.mn.x, S.clock.mn.y, m, S.clock.font_m, colors.text)
    write(S.clock.dt.x, S.clock.dt.y, date, 12, colors.text)
    write(S.clock.ut.x, S.clock.ut.y, "Uptime: " .. uptime_short(), 11, colors.text)
end


function draw_disks()
    for i, mount in ipairs(disk_mounts) do
        local ring = S.disk.rings[i]
        if not ring then break end
        local perc = fs_used_perc(mount.path)
        ring_anticlockwise(S.disk.x, S.disk.y, S.disk.radius + ring.offset, ring.thickness,
                           S.disk.begin_angle, S.disk.end_angle, perc, 100,
                           color_frompercent(tonumber(perc)))
        local n = mount.name:sub(1, 5)
        local label = string.format("%s: %s / %s (%s)",
            n:sub(1,1):upper() .. n:sub(2),
            fs_used(mount.path), fs_size(mount.path), fs_free(mount.path))
        write(S.disk.x+48, S.disk.y - S.disk.radius + 12 + (i-1)*17, label, 11, colors.text)
    end

    local dsk_info = {
        "Read:  " .. diskio_read(""),
        "Write:  " .. diskio_write(""),
    }
    write_line_by_line(S.disk.x-37, S.disk.y-13, 20, dsk_info, colors.text, 12)
end


function draw_net()
    ring_clockwise_log(S.net.x, S.net.y, S.net.radius,                       S.net.thickness, S.net.begin_angle, S.net.end_angle, download_speed_kb(), download_rate_maximum, colors.fg)
    ring_clockwise_log(S.net.x, S.net.y, S.net.radius + S.net.upload_offset, S.net.thickness, S.net.begin_angle, S.net.end_angle, upload_speed_kb(),   upload_rate_maximum,   colors.fg)

    write_right(S.net.indicators.down.x, S.net.indicators.down.y, download_speed(), 12, colors.text)
    write(S.net.indicators.down.x + 6, S.net.indicators.down.y + 5, "▼", 24, 0x2D9EEA, glyph_font)
    write_right(S.net.indicators.up.x, S.net.indicators.up.y, upload_speed(), 12, colors.text)
    write(S.net.indicators.up.x + 6, S.net.indicators.up.y + 3, "▲", 22, 0xF05555, glyph_font)

    write(S.net.total.label.x, S.net.total.label.y, "Total ", 12, colors.text)
    write(S.net.total.down.x, S.net.total.down.y, "▼ ".. download_total(), 12, colors.text, glyph_font)
    write(S.net.total.up.x, S.net.total.up.y, "▲ "..upload_total(), 12, colors.text, glyph_font)

    write(S.net.wifi_info.line1.x, S.net.wifi_info.line1.y, string.sub(ssid(), 0, 15) .. " (" .. wifi_signal() .. "%)", 12, colors.text)
    write(S.net.wifi_info.line2.x, S.net.wifi_info.line2.y, local_ip(), 12, colors.text)
end


function draw_battery()
    if not has_battery then return end
    if not initialized_battery and tonumber(updates()) > startup_delay + 6  then
        init_battery()
    end
    local bat = battery_percent()
    ring_anticlockwise(S.battery.x, S.battery.y, S.battery.radius, S.battery.width , S.battery.begin, S.battery.end_, bat, 100, color_frompercent_reverse(tonumber(bat)))
    write(S.battery.text.perc.x, S.battery.text.perc.y, bat .. "%", 15, colors.text)
    write(S.battery.text.title.x, S.battery.text.title.y, "Battery", 15, colors.text)
end


function draw_titles()
    if not to_draw_titles then return end
    write(S.cpu.ring_title.x - 5, S.cpu.ring_title.y,  "CPU", 18, colors.text)
    write(S.cpu.ring_title.x - 35, S.cpu.ring_title.y + 18, physical_cores .. " cores / " .. total_cores .. " threads", 11, colors.text)
    write(S.cpu.ring_title.x - 5, S.cpu.ring_title.y + 32, cpu_cores .. " of " .. physical_cores, 11, colors.text)
    write(S.net.ring_title.x, S.net.ring_title.y, "Network", 18, colors.text)
    write(S.mem.text.ring_title.x, S.mem.text.ring_title.y, "Memory", 18, colors.text)
    write(S.disk.ring_title.x, S.disk.ring_title.y, "File System", 18, colors.text)
end


function conky_main()
    if conky_window == nil then
        return
    elseif colors == nil then
        io.stderr:write("Fatal Error. Please define a theme")
    end

    local updates_ = tonumber(updates())
    -- if initialized_battery == false and updates_ > startup_delay  then
    --     init_battery()
    -- end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                                         conky_window.visual, conky_window.width,
                                         conky_window.height)
    cr = cairo_create(cs)

    start()

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    cr = nil
end


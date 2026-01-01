-- mGBA Bridge for Claude Code
-- Handles file-based I/O for AI control

-- Get the directory from the loaded script path
local base_dir = "./"

if script and script.path then
    local dir = script.path:match("(.*/)")
    if dir then
        base_dir = dir
    end
end

local input_dir = base_dir .. "input/"
local output_dir = base_dir .. "output/"
local command_file = input_dir .. "command.txt"
local screenshot_file = output_dir .. "screenshot.png"
local log_file = output_dir .. "log.txt"
local state_file = output_dir .. "game_state.json"

-- Frame counter
local frame_count = 0
local last_check_frame = 0
local check_interval = 6
local last_screenshot_frame = 0
local screenshot_interval = 30  -- Auto-screenshot every 30 frames (0.5 sec)

-- Button name to GBA key constant mapping
local button_map = {}

-- Command queue system
local command_queue = {}
local current_wait = 0
local default_button_wait = 12  -- Frames to wait after each button press

-- Pending operations for special commands
local pending_hold_key = nil
local pending_hold_frames = 0
local pending_mash_key = nil
local pending_mash_count = 0
local pending_mash_interval = 15
local pending_mash_timer = 0

function log(message)
    local timestamp = os.date("%H:%M:%S")
    local line = string.format("[%s] %s\n", timestamp, message)
    local f = io.open(log_file, "a")
    if f then
        f:write(line)
        f:close()
    end
    console:log(line)
end

function init_button_map()
    -- Try to get GBA key constants
    if C and C.GBA_KEY then
        button_map = {
            a = C.GBA_KEY.A,
            b = C.GBA_KEY.B,
            start = C.GBA_KEY.START,
            select = C.GBA_KEY.SELECT,
            up = C.GBA_KEY.UP,
            down = C.GBA_KEY.DOWN,
            left = C.GBA_KEY.LEFT,
            right = C.GBA_KEY.RIGHT,
            l = C.GBA_KEY.L,
            r = C.GBA_KEY.R
        }
        log("Using C.GBA_KEY constants")
    else
        -- Fallback to numeric values (GBA key bitmask positions)
        button_map = {
            a = 0,
            b = 1,
            select = 2,
            start = 3,
            right = 4,
            left = 5,
            up = 6,
            down = 7,
            r = 8,
            l = 9
        }
        log("Using numeric key constants")
    end
end

function take_screenshot()
    local ok, err = pcall(function()
        emu:screenshot(screenshot_file)
    end)
    if ok then
        log("Screenshot saved")
    else
        log("Screenshot error: " .. tostring(err))
    end
end

function read_game_state()
    local f = io.open(state_file, "w")
    if f then
        f:write("{\n")
        f:write(string.format('  "timestamp": "%s",\n', os.date("!%Y-%m-%dT%H:%M:%SZ")))
        f:write(string.format('  "frame": %d\n', frame_count))
        f:write("}\n")
        f:close()
    end
end

function press_key(key)
    local ok, err = pcall(function()
        emu:addKey(key)
    end)
    if not ok then
        log("addKey error: " .. tostring(err))
    end
end

function release_key(key)
    local ok, err = pcall(function()
        emu:clearKey(key)
    end)
    if not ok then
        log("clearKey error: " .. tostring(err))
    end
end

function clear_all_keys()
    local ok, err = pcall(function()
        emu:clearKeys(0xFFFF)
    end)
    if not ok then
        -- Try clearing individually
        for name, key in pairs(button_map) do
            pcall(function() emu:clearKey(key) end)
        end
    end
end

-- Add a command to the queue
function queue_command(cmd)
    table.insert(command_queue, cmd)
end

-- Process a single command (called from queue processor)
function execute_command(cmd)
    cmd = cmd:lower():gsub("^%s*(.-)%s*$", "%1")
    if cmd == "" then return 0 end

    local parts = {}
    for word in cmd:gmatch("%S+") do
        table.insert(parts, word)
    end

    local action = parts[1]
    local key = button_map[action]

    if key ~= nil then
        -- Simple button press
        clear_all_keys()
        press_key(key)
        log("Pressed: " .. action)
        return default_button_wait  -- Wait before next command

    elseif action == "wait" then
        local frames = tonumber(parts[2]) or 30
        clear_all_keys()
        log("Waiting " .. frames .. " frames")
        return frames

    elseif action == "hold" then
        local button = parts[2]
        local frames = tonumber(parts[3]) or 30
        local k = button_map[button]
        if k ~= nil then
            pending_hold_key = k
            pending_hold_frames = frames
            press_key(k)
            log("Holding " .. button .. " for " .. frames .. " frames")
        end
        return frames

    elseif action == "mash" then
        local button = parts[2] or "a"
        local times = tonumber(parts[3]) or 5
        local k = button_map[button]
        if k ~= nil then
            pending_mash_key = k
            pending_mash_count = times
            pending_mash_timer = 0
            log("Mashing " .. button .. " x" .. times)
        end
        return times * pending_mash_interval

    elseif action == "screenshot" then
        take_screenshot()
        return 0

    elseif action == "save_state" then
        local slot = tonumber(parts[2]) or 1
        pcall(function() emu:saveStateSlot(slot) end)
        log("State saved to slot " .. slot)
        return 0

    elseif action == "load_state" then
        local slot = tonumber(parts[2]) or 1
        pcall(function() emu:loadStateSlot(slot) end)
        log("State loaded from slot " .. slot)
        return 0

    else
        log("Unknown command: " .. cmd)
        return 0
    end
end

-- Commands that take arguments (don't split these)
local multi_word_commands = {
    wait = true, hold = true, mash = true,
    save_state = true, load_state = true
}

function check_commands()
    local f = io.open(command_file, "r")
    if not f then return end

    local content = f:read("*all")
    f:close()

    if not content or content:gsub("%s", "") == "" then
        return
    end

    -- Clear the command file
    f = io.open(command_file, "w")
    if f then
        f:write("")
        f:close()
    end

    -- Parse and queue commands
    for line in content:gmatch("[^\r\n]+") do
        line = line:lower():gsub("^%s*(.-)%s*$", "%1")
        if line ~= "" then
            -- Check if first word is a multi-word command
            local first_word = line:match("^(%S+)")
            if first_word and multi_word_commands[first_word] then
                -- Queue as single command with arguments
                queue_command(line)
            else
                -- Split by spaces and queue each as separate command
                for cmd in line:gmatch("%S+") do
                    queue_command(cmd)
                end
            end
        end
    end

    log("Queued " .. #command_queue .. " commands")
end

function process_queue()
    -- Don't process if we're still waiting
    if current_wait > 0 then
        current_wait = current_wait - 1
        if current_wait == 0 then
            clear_all_keys()
        end
        return
    end

    -- Process next command from queue
    if #command_queue > 0 then
        local cmd = table.remove(command_queue, 1)
        current_wait = execute_command(cmd)

        -- Take screenshot when queue is empty
        if #command_queue == 0 then
            take_screenshot()
            read_game_state()
        end
    end
end

function on_frame()
    frame_count = frame_count + 1

    -- Process command queue
    process_queue()

    -- Handle pending hold
    if pending_hold_key ~= nil then
        pending_hold_frames = pending_hold_frames - 1
        if pending_hold_frames <= 0 then
            release_key(pending_hold_key)
            pending_hold_key = nil
        end
    end

    -- Handle pending mash
    if pending_mash_key ~= nil and pending_mash_count > 0 then
        pending_mash_timer = pending_mash_timer + 1
        if pending_mash_timer >= pending_mash_interval then
            pending_mash_timer = 0
            press_key(pending_mash_key)
            pending_mash_count = pending_mash_count - 1
            current_wait = 5
            if pending_mash_count <= 0 then
                pending_mash_key = nil
            end
        end
    end

    -- Check for new commands periodically
    if frame_count - last_check_frame >= check_interval then
        last_check_frame = frame_count
        check_commands()
    end

    -- Auto-screenshot at regular intervals
    if frame_count - last_screenshot_frame >= screenshot_interval then
        last_screenshot_frame = frame_count
        take_screenshot()
        read_game_state()
    end
end

-- Initialize
init_button_map()
log("mGBA Bridge started")
log("Watching: " .. command_file)

-- Take initial screenshot
take_screenshot()
read_game_state()

-- Register frame callback
callbacks:add("frame", on_frame)

console:log("Bridge initialized. Watching for commands...")

-- TA4 Quarry Configuration Tool
-- Sneak + left click  | start selected quarries
-- Sneak + right click | copy settings
-- Left click          | select / deselect quarry
-- Right click         | apply to selected quarries
-- Requires 120 techage exp to use

local REQUIRED_EXP = 120

local function pos_to_key(pos)
    return minetest.pos_to_string(pos)
end

local function key_to_pos(str)
    return minetest.string_to_pos(str)
end

-- Read settings from a TA4 quarry
local function read_quarry_settings(pos)
    local nvm = techage.get_nvm(pos)
    if not nvm then return end

    return {
        start_level   = nvm.start_level or 0,
        quarry_depth  = nvm.quarry_depth or 1,
        hole_size     = nvm.hole_size or "5x5",
        hole_diameter = nvm.hole_diameter or 5,
    }
end

-- Apply settings to a TA4 quarry
local function apply_quarry_settings(pos, settings)
    local nvm = techage.get_nvm(pos)
    local mem = techage.get_mem(pos)
    local def = minetest.registered_nodes[minetest.get_node(pos).name]
    local crd = def and def.consumer

    if not (nvm and mem and crd) then return end

    local changed = false

    if settings.start_level ~= nvm.start_level then
        nvm.start_level = settings.start_level
        changed = true
    end

    if settings.quarry_depth ~= nvm.quarry_depth then
        nvm.quarry_depth = settings.quarry_depth
        changed = true
    end

    if settings.hole_size ~= nvm.hole_size then
        nvm.hole_size = settings.hole_size
        nvm.hole_diameter = settings.hole_diameter
        changed = true
    end

    if changed then
        mem.co = nil
        crd.State:stop(pos, nvm)
    end
end

minetest.register_tool("quarry_controller:quarry_config_tool", {
    description = "TA4 Quarry Configuration Tool",
    inventory_image = "quarry_config_tool.png",

    -------------------------------------------------
    -- LEFT CLICK
    -------------------------------------------------
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type ~= "node" then
            return itemstack
        end

        local name = user:get_player_name()
        local exp = techage.get_expoints(user) or 0

        if exp < REQUIRED_EXP then
            minetest.chat_send_player(name,
                "✖ You need at least " .. REQUIRED_EXP .. " exp to use this tool."
            )
            return itemstack
        end

        local pos = pointed_thing.under
        local node = minetest.get_node(pos)
        if not node.name:find("quarry") then return itemstack end
        if minetest.is_protected(pos, name) then return itemstack end

        local meta = itemstack:get_meta()
        local key = pos_to_key(pos)
        local raw = meta:get_string("selected")
        local selected = {}
        for p in raw:gmatch("[^;]+") do selected[p] = true end

        local ctrl = user:get_player_control()

        -- Sneak + LEFT CLICK → turn on all selected quarries
        if ctrl.sneak then
            local count = 0
            for k in pairs(selected) do
                local qpos = key_to_pos(k)
                if qpos then
                    local nvm = techage.get_nvm(qpos)
                    local def = minetest.registered_nodes[minetest.get_node(qpos).name]
                    local crd = def and def.consumer
                    if crd and nvm then
                        crd.State:start(qpos, nvm)
                        count = count + 1
                    end
                end
            end
            minetest.chat_send_player(name, "✔ Turned on " .. count .. " quarries")
            return itemstack
        end

        -- NORMAL LEFT CLICK → select / deselect quarry
        if selected[key] then
            selected[key] = nil
            minetest.chat_send_player(name, "✖ Quarry deselected")
        else
            selected[key] = true
            minetest.chat_send_player(name, "✔ Quarry selected")
        end

        local out = {}
        for k in pairs(selected) do table.insert(out, k) end
        meta:set_string("selected", table.concat(out, ";"))

        return itemstack
    end,

    -------------------------------------------------
    -- RIGHT CLICK
    -- Sneak → copy settings
    -- Normal → apply settings
    -------------------------------------------------
    on_place = function(itemstack, user, pointed_thing)
        if pointed_thing.type ~= "node" then
            return itemstack
        end

        local name = user:get_player_name()
        local exp = techage.get_expoints(user) or 0

        if exp < REQUIRED_EXP then
            minetest.chat_send_player(name,
                "✖ You need at least " .. REQUIRED_EXP .. " exp to use this tool."
            )
            return itemstack
        end

        local pos = pointed_thing.under
        local node = minetest.get_node(pos)
        if not node.name:find("quarry") then return itemstack end
        if minetest.is_protected(pos, name) then return itemstack end

        local meta = itemstack:get_meta()
        local ctrl = user:get_player_control()

        -- SNEAK + RIGHT CLICK → copy settings
        if ctrl.sneak then
            local settings = read_quarry_settings(pos)
            if not settings then return itemstack end

            meta:set_int("start_level", settings.start_level)
            meta:set_int("quarry_depth", settings.quarry_depth)
            meta:set_string("hole_size", settings.hole_size)
            meta:set_int("hole_diameter", settings.hole_diameter)

            meta:set_string("description",
                "TA4 Quarry Config Tool\n" ..
                "Start level: " .. settings.start_level ..
                "\nDepth: " .. settings.quarry_depth ..
                "\nSize: " .. settings.hole_size
            )

            minetest.chat_send_player(name, "✔ Quarry settings copied")
            return itemstack
        end

        -- NORMAL RIGHT CLICK → apply settings to selected quarries
        local hole_size = meta:get_string("hole_size")
        if hole_size == "" then
            minetest.chat_send_player(name, "✖ No settings stored")
            return itemstack
        end

        local raw = meta:get_string("selected")
        if raw == "" then
            minetest.chat_send_player(name, "✖ No quarries selected")
            return itemstack
        end

        local settings = {
            start_level   = meta:get_int("start_level"),
            quarry_depth  = meta:get_int("quarry_depth"),
            hole_size     = hole_size,
            hole_diameter = meta:get_int("hole_diameter"),
        }

        local count = 0
        for p in raw:gmatch("[^;]+") do
            local qpos = key_to_pos(p)
            if qpos then
                apply_quarry_settings(qpos, settings)
                count = count + 1
            end
        end

        meta:set_string("selected", "")
        minetest.chat_send_player(name,
            "✔ Applied settings to " .. count .. " quarries"
        )

        return itemstack
    end,
})





minetest.register_craftitem("quarry_controller:super_diamond", {
    description = "Super Diamond",
    inventory_image = "quarry_diamond.png"
})

minetest.register_craft({
    output = "quarry_controller:super_diamond",
    recipe = {
        {"default:diamondblock", "default:diamondblock", "default:diamondblock"},
        {"default:diamondblock", "default:diamondblock", "default:diamondblock"},
        {"default:diamondblock", "default:diamondblock", "default:diamondblock"}
    }
})

minetest.register_node("quarry_controller:super_diamond_block", {
    description = ("Super Diamond Block"),
    tiles = {"quarry_diamond_block.png"},
    groups = {cracky = 1}
})

minetest.register_craft({
    output = "quarry_controller:super_diamond_block",
    recipe = {
        {"quarry_controller:super_diamond", "quarry_controller:super_diamond", "quarry_controller:super_diamond"},
        {"quarry_controller:super_diamond", "quarry_controller:super_diamond", "quarry_controller:super_diamond"},
        {"quarry_controller:super_diamond", "quarry_controller:super_diamond", "quarry_controller:super_diamond"}
    }
})

minetest.register_craftitem("quarry_controller:quarry_stick", {
    description = "Quarry Stick",
    inventory_image = "quarry_stick.png"
})

minetest.register_craft({
    output = "quarry_controller:quarry_stick",
    recipe = {
        {"techage:ta4_quarry_pas","techage:ta4_quarry_pas","techage:ta4_quarry_pas"},
        {"techage:ta4_quarry_pas","techage:ta4_quarry_pas","techage:ta4_quarry_pas"},
        {"techage:ta4_quarry_pas","techage:ta4_quarry_pas","techage:ta4_quarry_pas"}
    }
})

minetest.register_craft({
    output = "quarry_controller:quarry_config_tool",
    recipe = {
        {"quarry_controller:super_diamond_block", "quarry_controller:super_diamond_block", "quarry_controller:super_diamond_block"},
        {"", "quarry_controller:quarry_stick", ""},
        {"", "quarry_controller:quarry_stick", ""},
    }
})



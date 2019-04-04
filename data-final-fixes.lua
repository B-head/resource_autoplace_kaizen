local autoplace = require("autoplace")
local vanilla_autoplace = require("__base__.prototypes.entity.demo-resource-autoplace")
local noise = require("noise")

local function expression_to_flat(exp, parent, _ret_list)
    if not _ret_list then
        _ret_list = {}
    end
    exp.parent = parent
    table.insert(_ret_list, exp)
    if exp.type == "function-application" then
        for k, v in pairs(exp.arguments) do
            _ret_list = expression_to_flat(v, exp, _ret_list)
        end
    elseif exp.type == "literal-expression" then
        _ret_list = expression_to_flat(exp.literal_value, exp, _ret_list)
    elseif exp.type == "procedure-delimiter" then
        _ret_list = expression_to_flat(exp.expression, exp, _ret_list)
    elseif exp.type == "noise-expression" then
        _ret_list = expression_to_flat(exp.expression, exp, _ret_list)
    end
    return _ret_list
end

local function unique(list)
    local set = {}
    local ret = {}
    for i, v in ipairs(list) do
        if not set[v] then
            set[v] = true
            table.insert(ret, v)
        end
    end
    return ret
end

local function table_to_string(table)
    local ret = "{ "
    for k, v in pairs(table) do
        if ret ~= "{ " then
            ret = ret..", "
        end
        ret = ret..k.."="..tostring(v)
    end
    return ret.." }"
end

local function parent_to_name(index, exp)
    if exp == nil then
        return "["..index.."] Root"
    end
    local ret = "["..exp.index.."].["..index.."] "..exp.type
    if exp.type == "function-application" then
        ret = ret.." "..exp.function_name.."()"
    end
    return ret
end

local function is_funcapp(exp, function_name)
    if not exp then
        return false
    end
    return exp.type == "function-application" and exp.function_name == function_name
end

local function is_control(exp, control_name)
    if exp.type ~= "variable" then
        return false
    end
    local captcha1 = string.match(exp.variable_name, "control%-setting:[^:]+:([^:]+):multiplier")
    return captcha1 == control_name
end

local function salvage_impl(exp, ret_params)
    local void
    local p = exp.parent
    local value = exp.literal_value 
    if is_funcapp(p, "add") then
        local lhs, rhs = table.unpack(p.arguments)
        if rhs == exp then
            local a = lhs
            if is_funcapp(a, "divide") then
                a, void = table.unpack(a.arguments)
            end
            if a.type == "procedure-delimiter" then
                ret_params.additional_richness = value
            end
        end
    elseif is_funcapp(p, "multiply") then
        local lhs, rhs = table.unpack(p.arguments)
        if lhs == exp then
            if is_funcapp(rhs, "multiply") and is_control(rhs.arguments[1], "frequency") and is_control(rhs.arguments[2], "size") then
                ret_params.base_density = value
            elseif is_control(rhs, "frequency") then
                ret_params.base_spots_per_km2 = value
            elseif is_control(rhs, "richness") then
                ret_params.richness_post_multiplier = value
            end
        end
        if is_funcapp(p.parent, "clamp") and p.parent.parent.type == "literal-expression" and is_funcapp(p.parent.parent.parent, "spot-noise") then
            local spot = p.parent.parent.parent
            local litexp = p.parent.parent
            if spot.arguments.spot_radius_expression == litexp then
                ret_params.regular_rq_factor = value
            end
        elseif p.parent.type == "literal-expression" and is_funcapp(p.parent.parent, "spot-noise") then
            local spot = p.parent.parent
            local litexp = p.parent
            if spot.arguments.spot_radius_expression == litexp then
                ret_params.starting_rq_factor = value
            end
        end
    elseif is_funcapp(p, "divide") then
        local lhs, rhs = table.unpack(p.arguments)
        if rhs == exp then
            if lhs.type == "procedure-delimiter" then
                ret_params.random_probability = value
            end
        end
    elseif is_funcapp(p, "random-penalty") then
        if is_funcapp(p.parent, "multiply") then
            local source = p.arguments.source.literal_value
            local amplitude = p.arguments.amplitude.literal_value
            ret_params.random_spot_size_minimum = source - amplitude
            ret_params.random_spot_size_maximum = source
        end
    elseif is_funcapp(p, "clamp") then
        local a, min, max = table.unpack(p.arguments)
        if min == exp then
            if is_funcapp(a, "add") then
                a, void = table.unpack(a.arguments)
            end
            if is_funcapp(a, "divide") then
                a, void = table.unpack(a.arguments)
            end
            if a.type == "procedure-delimiter" then
                ret_params.minimum_richness = value
            end
        end
    end
    return ret_params
end

local function salvage_parameters(autoplace_settings)
    local flatted = unique(expression_to_flat(autoplace_settings.richness_expression))
    for i, v in ipairs(flatted) do
        v.index = i
    end
    local ret = { 
        name = autoplace_settings.control, 
        order = autoplace_settings.order,
        tile_restriction = autoplace_settings.tile_restriction,
    }
    for i, v in ipairs(flatted) do
        -- autoplace.dump_expression(parent_to_name(v.index, v.parent), v)
        if v.type == "literal-number" then
            ret = salvage_impl(v, ret)
        elseif is_funcapp(v, "spot-noise") then
            ret.resource_index = v.arguments.skip_offset.literal_value
        elseif v.type == "procedure-delimiter" and is_funcapp(v.expression, "clamp") then
            ret.has_starting_area_placement = true
        elseif v.type == "variable" and v.variable_name == "distance" and is_funcapp(v.parent, "subtract") then
            local lhs, rhs = table.unpack(v.parent.arguments)
            if lhs == v and ret.has_starting_area_placement == nil then
                ret.has_starting_area_placement = false
            end
        end
    end
    return ret
end

-- salvage test.
local test_as = vanilla_autoplace.resource_autoplace_settings{
    name = "crude-oil",
    order = "c", 
    base_density = 8.2,
    base_spots_per_km2 = 1.8,
    random_probability = 0.026,
    random_spot_size_minimum = 0.88,
    random_spot_size_maximum = 2.22,
    additional_richness = 220000,
    minimum_richness = 110000,
    richness_post_multiplier = 3.33,
    has_starting_area_placement = true,
    resource_index = 7,
}
local test_params = salvage_parameters(test_as)
log("test = "..table_to_string(test_params))

for k, v in pairs(data.raw["resource"]) do
    local as = v.autoplace or {}
    log("check "..k.." = "..table_to_string(as))
    if as.is_kaizen then
        -- no operation
    elseif autoplace._maked_resources[as.control] then
        v.autoplace = autoplace._maked_resources[as.control]
    elseif as.richness_expression then
        local params = salvage_parameters(as)
        log(as.control.." old = "..table_to_string(params))
        local average_random_size_multiplier = (params.random_spot_size_minimum + params.random_spot_size_maximum) / 2
        local richness_multiplier = params.richness_post_multiplier
        local richness = params.base_density * params.richness_post_multiplier * average_random_size_multiplier
        local rq_factor = math.min(params.starting_rq_factor or math.huge, params.regular_rq_factor)
        local additional = math.max(params.additional_richness or 0, params.minimum_richness or 0)
        local new_params = {
            control_name = params.name,
            seed = params.resource_index,
            order = params.order,
            tile_restriction = params.tile_restriction,
            discovery_level = params.has_starting_area_placement,
            starting_richness = richness,
            regular_richness = richness,
            additional_richness = richness_multiplier * additional / 2000,
            patch_count_per_kt2 = params.base_spots_per_km2 / 2.5,
            resource_density = richness_multiplier / 5 / rq_factor ^ 3,
            patch_size_fluctuance = 1 - params.random_spot_size_minimum / average_random_size_multiplier,
            tile_occurrence_probability = params.random_probability,
            enabled_blobbiness = true,
        }
        log(as.control.." new = "..table_to_string(new_params))
        v.autoplace = autoplace.make_resource(new_params)
    else
        -- todo: also converts the old autoplace settings.
    end
end


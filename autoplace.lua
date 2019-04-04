local noise = require("noise")
local expression_to_ascii_math = require("noise.expression-to-ascii-math")
local tne = noise.to_noise_expression

local base_multiplier = 1/25
local blob_multiplier = 1/8
local density_fixed_bias = 4
local enemy_base_density_multiplier = 1/50

local first_level_radius = 32 * 4
local discovery_level_base_radius = 32 * 12
local enlarge_effect_distance = 32 * 12
local fade_in_range = 32 * 4
local starting_area_base_radius = 32 * 8
local max_regular_spot_radius = 128
local max_starting_spot_base_radius = 16
local max_enemy_base_radius = 256

local max_starting_resources = 8
local kilo_amount = 1024
local kilo2_amount = kilo_amount * kilo_amount
local region_size_multiplier = 4
local onehalf = 1/2
local onethird = 1/3

if not data.seed_to_index_dictionary then
  data.seed_to_index_dictionary = {}
end
if not data.next_resource_indexes then
  data.next_resource_indexes = {}
end

local function get_resource_index(seed, discovery_level)
  local stid = data.seed_to_index_dictionary
  local nri = data.next_resource_indexes
  if not stid[discovery_level] then
    stid[discovery_level] = {}
  end
  if stid[discovery_level][seed] then
    return stid[discovery_level][seed]
  end
  if not nri[discovery_level] then
    nri[discovery_level] = 0
  end
  local resource_index = nri[discovery_level]
  if resource_index >= max_starting_resources * (discovery_level + 1) then
    error("discovery level "..discovery_level.." resources has exceeded the upper limit.", 3)
  end
  nri[discovery_level] = resource_index + 1
  stid[discovery_level][seed] = resource_index
  return resource_index
end

local function litexp(value)
  local v = tne(value)
  if v.type == "literal-expression" then
    return v
  else
    return { type = "literal-expression", literal_value = v }
  end
end

local function dump_expression(name, expr)
  log(name..":\n"..tostring(expression_to_ascii_math(expr)))
end

local function hash(str)
  if type(str) == "number" then
    return str
  end
  local x = 123456789
  for i = 1, #str do
    x = bit32.bxor(x, str:byte(i))
    x = bit32.bxor(x, bit32.lshift(x, 13))
    x = bit32.bxor(x, bit32.rshift(x, 17))
    x = bit32.bxor(x, bit32.lshift(x, 5))
  end
  return x
end

local function absolute(...)
  return noise.function_application("absolute-value", {...})
end

local function basis_noise(scale, amplitude, seed)
  local s = seed or hash"blob"
  return noise.function_application("factorio-basis-noise", {
    x = noise.var("x"),
    y = noise.var("y"),
    seed0 = noise.var("map_seed"),
    seed1 = s % 256,
    input_scale = 1 / scale,
    output_scale = amplitude 
  })
end

local function spot_noise(arguments)
  arguments.x = arguments.x or noise.var("x")
  arguments.y = arguments.y or noise.var("y")
  arguments.seed0 = arguments.seed0 or noise.var("map_seed")
  arguments.seed1 = arguments.seed1 or arguments.seed or noise.var("map_seed")
  arguments.hard_region_target_quantity = arguments.hard_region_target_quantity or false
  arguments.basement_value = arguments.basement_value or -math.huge
  arguments.maximum_spot_basement_radius = arguments.maximum_spot_basement_radius or math.huge
  arguments.density_expression = litexp(arguments.density_expression or 1)
  arguments.spot_quantity_expression = litexp(arguments.spot_quantity_expression or 1)
  arguments.spot_radius_expression = litexp(arguments.spot_radius_expression or 1)
  arguments.spot_favorability_expression = litexp(arguments.spot_favorability_expression or 1)
  return noise.function_application("spot-noise", arguments)
end

local function spot_peek_height(quantity, radius)
  if type(quantity) == "table" and quantity.function_name == "spot-noise" then
    local spot_noise = quantity
    quantity = spot_noise.arguments.spot_quantity_expression.literal_value
    radius = spot_noise.arguments.spot_radius_expression.literal_value
  end
  return 3 * quantity / (math.pi * radius^2)
end

local maked_resources = {}
local function make_resource(params)
  local control_name = params.control_name
  local seed = params.seed or control_name
  local order = params.order or "z"
  local tile_restriction = params.tile_restriction or {}
  local discovery_level = params.discovery_level
  
  local starting_richness = params.starting_richness or 1
  local regular_richness = params.regular_richness or 1
  local additional_richness = params.additional_richness or 0
  local patch_count_per_kt2 = params.patch_count_per_kt2 or 1
  local resource_density = params.resource_density or 200

  local patch_size_fluctuance = params.patch_size_fluctuance or 1/2
  local tile_occurrence_probability = params.tile_occurrence_probability or 1
  local enabled_blobbiness = params.enabled_blobbiness or true

  local control_setting = noise.get_control_setting(control_name)
  local richness_multiplier =  control_setting.richness_multiplier
  local frequency_multiplier = control_setting.frequency_multiplier
  local size_multiplier = control_setting.size_multiplier


  local distance_from_center = noise.var("distance")
  local elevation = noise.var("normalize_elevation")
  local elevation_favorability = noise.var("kaizen_elevation_favorability")
  local kaizen_unforest_favorability = noise.var("kaizen_unforest_favorability")
  local random_expression = noise.random_between(1 - patch_size_fluctuance, 1 + patch_size_fluctuance)

  function make_starting_placement_mask(begin_radius, end_radius)
    return noise.clamp(distance_from_center - begin_radius, 0, 1) * noise.clamp(end_radius - distance_from_center, 0, 1)
  end

  function make_regular_placement_mask(fade_in_distance)
    return noise.clamp((distance_from_center - fade_in_distance) / fade_in_range, 0, 1)
  end

  function make_enlarge_effect_expression(begin_enlarge_distance)
    return noise.max((distance_from_center - begin_enlarge_distance) / enlarge_effect_distance + 1, 1) 
  end

  local resource_index
  local starting_region_size
  local max_starting_spot_radius
  local starting_placement_mask 
  local regular_placement_mask
  local enlarge_effect_expression
  if discovery_level then
    local begin_radius
    local end_radius
    if discovery_level == true then
      discovery_level = 1
    end
    if discovery_level == 0 then
      begin_radius = 0
      end_radius = first_level_radius
    elseif discovery_level == 1 then
      begin_radius = first_level_radius
      end_radius = discovery_level_base_radius
    else
      begin_radius = discovery_level_base_radius * (discovery_level - 1)
      end_radius = discovery_level_base_radius * (discovery_level)
    end

    resource_index = get_resource_index(seed, discovery_level)
    starting_region_size = end_radius
    max_starting_spot_radius = math.min(max_starting_spot_base_radius * (discovery_level + 1), max_regular_spot_radius)
    starting_placement_mask = make_starting_placement_mask(begin_radius, end_radius)
    regular_placement_mask = make_regular_placement_mask(begin_radius)
    enlarge_effect_expression = make_enlarge_effect_expression(end_radius)
  else
    local begin_radius
    local end_radius
    if discovery_level == false then
      begin_radius = starting_area_base_radius
      end_radius = starting_area_base_radius + discovery_level_base_radius
    else
      begin_radius = -fade_in_range
      end_radius = 0
    end
    discovery_level = 0
    resource_index = 0
    starting_region_size = 0
    max_starting_spot_radius = 0
    starting_placement_mask = tne(0)
    regular_placement_mask = make_regular_placement_mask(begin_radius)
    enlarge_effect_expression = make_enlarge_effect_expression(end_radius)
  end
  log(control_name..".resource_index = "..tostring(resource_index))
  log(control_name..".starting_placement_mask = "..tostring(starting_region_size))
  log(control_name..".max_starting_spot_radius = "..tostring(max_starting_spot_radius))
  dump_expression(control_name..".starting_placement_mask", starting_placement_mask)
  dump_expression(control_name..".regular_placement_mask", regular_placement_mask)
  dump_expression(control_name..".enlarge_effect_expression", enlarge_effect_expression)

  local regular_richness_expression = regular_richness * base_multiplier * size_multiplier * enlarge_effect_expression ^ 2
  local starting_richness_expression = starting_richness * base_multiplier * size_multiplier
  local density_multiplier = patch_count_per_kt2 * frequency_multiplier
  local center_favorability = noise.clamp(1 - distance_from_center / starting_region_size, 0, 1)
  local candidate_point_spacing = max_starting_spot_base_radius * 1.5

  function make_spot_radius_expression(richness_expression)
    return (kilo2_amount * richness_expression / resource_density) ^ (onethird)
  end

  local regular_spots = spot_noise{
    seed = hash(seed),
    region_size =  kilo_amount * region_size_multiplier,
    maximum_spot_basement_radius = max_regular_spot_radius,

    density_expression = density_fixed_bias * density_multiplier * regular_placement_mask / enlarge_effect_expression, 
    spot_quantity_expression = kilo2_amount * random_expression, 
    spot_radius_expression = make_spot_radius_expression(regular_richness_expression * random_expression),
    spot_favorability_expression = (elevation_favorability + kaizen_unforest_favorability) * regular_placement_mask,
  }

  local starting_spots = spot_noise{
    seed = hash"resource",
    region_size = starting_region_size * 2,
    skip_offset = resource_index,
    skip_span = max_starting_resources * (discovery_level + 1),
    candidate_point_count = math.min((starting_region_size * 2) ^ 2 / (candidate_point_spacing) ^ 2, 10000),
    minimum_candidate_point_spacing = candidate_point_spacing,
    maximum_spot_basement_radius = max_starting_spot_radius,

    density_expression = density_multiplier * starting_placement_mask,
    spot_quantity_expression = kilo2_amount,
    spot_radius_expression = make_spot_radius_expression(starting_richness_expression),
    spot_favorability_expression = (elevation_favorability + kaizen_unforest_favorability + center_favorability * 2) * starting_placement_mask,
  }

  local regular_patches = regular_spots
  local starting_patches = starting_spots
  if enabled_blobbiness then
    local starting_blob_expression = basis_noise(8, 1) + basis_noise(24, 1)
    local regular_blob_expression = starting_blob_expression + basis_noise(64, 1.5)
    regular_patches = regular_patches + regular_blob_expression * spot_peek_height(regular_spots) * blob_multiplier
    starting_patches = starting_patches + starting_blob_expression * spot_peek_height(starting_spots) * blob_multiplier
  end

  regular_patches = noise.delimit_procedure(regular_patches) * regular_richness_expression
  starting_patches = noise.delimit_procedure(starting_patches) * starting_richness_expression

  local all_patches
  if discovery_level then
    all_patches = noise.max(starting_patches, regular_patches)
  else
    all_patches = regular_patches
  end

  local richness_expression = all_patches
  local additional_richness_expression = additional_richness * base_multiplier * enlarge_effect_expression
  local additional_spot_area = math.pi * make_spot_radius_expression(regular_richness_expression) ^ 2
  richness_expression = richness_expression + kilo2_amount * additional_richness_expression / additional_spot_area
  richness_expression = richness_expression * (richness_multiplier / tile_occurrence_probability)
  
  local ret = {
    is_kaizen = true,
    control = control_name,
    order = order,
    tile_restriction = tile_restriction,
    richness_expression = richness_expression,
    probability_expression = noise.clamp(all_patches, 0, 1) * tile_occurrence_probability,
  }
  maked_resources[control_name] = ret
  return ret
end

local function make_enemy_base(discovery_level, order, probability)
  local control_setting = noise.get_control_setting"enemy-base"
  local size_multiplier = control_setting.size_multiplier
  local frequency_multiplier = control_setting.frequency_multiplier

  local distance_from_center = noise.var("distance")
  local elevation = noise.var("normalize_elevation")
  local starting_area_radius = noise.var("kaizen_starting_area_radius")
  local enemy_base_density = noise.max(0, noise.var("enemy_base_density"))
  local enemy_base_size = noise.max(0, noise.var("enemy_base_size"))
  local elevation_favorability = noise.var("kaizen_elevation_favorability")
  local kaizen_unforest_favorability = noise.var("kaizen_unforest_favorability")

  local density_multiplier = size_multiplier * frequency_multiplier * enemy_base_density_multiplier
  local enemy_base_radius = size_multiplier * enemy_base_size ^ onehalf

  local enemy_base_placement_mask
  if discovery_level == 0 then
    enemy_base_placement_mask = noise.clamp(distance_from_center - starting_area_radius, 0, 1)
  elseif discovery_level == 1 then
    enemy_base_placement_mask = noise.clamp((distance_from_center - starting_area_radius) / first_level_radius, 0, 1)
  else
    local fade_in_distance = starting_area_radius + first_level_radius + discovery_level_base_radius * (discovery_level - 2)
    enemy_base_placement_mask = noise.clamp((distance_from_center - fade_in_distance) / discovery_level_base_radius, 0, 1)
  end

  local spots = spot_noise{
    seed = hash"enemy-base",
    maximum_spot_basement_radius = max_enemy_base_radius,

    density_expression = enemy_base_density * density_multiplier,
    spot_quantity_expression = math.pi * onethird * enemy_base_radius ^ 2,
    spot_radius_expression = enemy_base_radius,
    spot_favorability_expression = (elevation_favorability + kaizen_unforest_favorability),
  }

  local blob_expression = basis_noise(8, 1) + basis_noise(24, 1) + basis_noise(64, 2)
  local base_patch = spots + blob_expression * spot_peek_height(spots) * blob_multiplier

  local probability_expression = noise.delimit_procedure(base_patch)
  probability_expression = probability_expression * enemy_base_placement_mask * probability
  
  return {
    control = "enemy-base",
    order = order,
    force = "enemy",
    richness_expression = tne(1),
    probability_expression = probability_expression,
  }
end

local function make_factor_effect(factor, min, max)
  local average = (min + max) / 2
  local fade = average - min
  return noise.clamp((fade + factor - min) / fade, 0, 1) * noise.clamp((fade + max - factor) / fade, 0, 1)
end

local function make_rock(order, probability, min_moisture, max_moisture, min_aux, max_aux)
  local elevation = noise.var("normalize_elevation")
  local moisture = noise.var("moisture")
  local aux = noise.var("aux")
  local elevation_favorability = noise.var("kaizen_elevation_favorability")

  local elevation_factor = noise.clamp(1 - elevation_favorability * 2, 0, 1)
  local moisture_factor = make_factor_effect(moisture, min_moisture, max_moisture)
  local aux_factor = make_factor_effect(aux, min_aux, max_aux)
  local probability_expression = elevation_factor * moisture_factor * aux_factor * probability

  return {
    order = order,
    richness_expression = tne(1),
    probability_expression = probability_expression,
  }
end

local function make_tree(order, probability, min_moisture, max_moisture, min_temperature, max_temperature)
  local forest = noise.var("forest")
  local moisture = noise.var("moisture")
  local temperature = noise.var("kaizen_temperature")

  local moisture_factor = make_factor_effect(moisture, min_moisture, max_moisture)
  local temperature_factor = make_factor_effect(temperature, min_temperature, max_temperature)

  local richness_expression = moisture_factor * temperature_factor
  local probability_expression = forest * moisture_factor * temperature_factor * probability

  return {
    control = "trees",
    order = order,
    richness_expression = richness_expression,
    probability_expression = probability_expression,
  }
end

-- test expression
-- data.raw["resource"]["uranium-ore"].autoplace = {
--   is_kaizen = true,
--   control = "uranium-ore",
--   order = "z",
--   richness_expression = noise.var("kaizen_temperature") * 1000,
--   probability_expression = tne(1),
-- }

data:extend{
  {
    type = "noise-expression",
    name = "kaizen_starting_area_radius",
    expression = noise.define_noise_function( function(x,y,tile,map)
      -- local starting_area_multiplier = noise.var("control-setting:starting_area_radius:size:multiplier")
      local starting_area_multiplier = noise.var("starting_area_radius") / 150
      return starting_area_base_radius * starting_area_multiplier ^ onehalf
    end)
  },
  -- {
  --   type = "noise-expression",
  --   name = "starting_area_radius",
  --   expression = noise.var("kaizen_starting_area_radius")
  -- },
  {
    type = "noise-expression",
    name = "normalize_elevation",
    expression = noise.define_noise_function( function(x,y,tile,map)
      local distance_from_center = noise.var("distance")
      local elevation = noise.var("elevation")
      local starting_area_fixed_elevation = noise.clamp(1 - distance_from_center / starting_area_base_radius, 0, 1) / 8
      return elevation / 64 + starting_area_fixed_elevation
    end)
  },
  {
    type = "noise-expression",
    name = "kaizen_elevation_favorability",
    expression = noise.define_noise_function( function(x,y,tile,map)
      local elevation = noise.var("normalize_elevation")
      return noise.clamp(elevation, 0, 1/4) * 4
    end)
  },
  {
    type = "noise-expression",
    name = "forest",
    expression = noise.define_noise_function( function(x,y,tile,map)
      local scale = noise.var("control-setting:trees:frequency:multiplier")
      local caverage = noise.var("control-setting:trees:size:multiplier")
      local distance_from_center = noise.var("distance")
      local moisture = noise.var("moisture")
      local noise_expression = basis_noise(64 / scale, 1) + basis_noise(160 / scale, 2) / 3
      local outside_starting_area_factor = noise.clamp(1 - distance_from_center / starting_area_base_radius, 0, 1)
      local bias = caverage * (moisture ^ 2) - 1 - outside_starting_area_factor
      return (noise_expression + bias) / (1 + absolute(bias))
    end)
  },
  {
    type = "noise-expression",
    name = "kaizen_unforest_favorability",
    expression = noise.define_noise_function( function(x,y,tile,map)
      local forest = noise.var("forest")
      return noise.clamp(-1 * forest, 0, 1/2) * 2
    end)
  },
  {
    type = "noise-expression",
    name = "kaizen_temperature",
    expression = noise.define_noise_function( function(x,y,tile,map)
      local temperature = noise.var("temperature")
      return 15 + (temperature - 15) * 10 
    end)
  },
  {
    type = "noise-expression",
    name = "enemy_base_size",
    expression = noise.define_noise_function( function(x,y,tile,map)
      return noise.var("distance")
    end)
  },
  {
    type = "noise-expression",
    name = "enemy_base_density",
    expression = noise.define_noise_function( function(x,y,tile,map)
      local moisture = noise.var("moisture")
      local aux = noise.var("aux")
      return (1 + moisture * 6 + aux) / 8
    end)
  },
}

return {
  dump_expression = dump_expression,
  hash = hash,
  absolute = absolute,
  basis_noise = basis_noise,
  blob_noise = basis_noise,
  spot_noise = spot_noise,
  basic_spot_noise = spot_noise,
  spot_peek_height = spot_peek_height,
  _maked_resources = maked_resources,
  make_resource = make_resource,
  make_enemy_base = make_enemy_base,
  make_rock = make_rock,
  make_tree = make_tree,
}
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
local fade_in_range = 32 * 6
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

local function blob_noise(scale, amplitude, seed)
  local s = seed or hash"blob" 
  return noise.function_application("factorio-basis-noise", {
    x = noise.var("x"),
    y = noise.var("y"),
    seed0 = noise.var("map_seed"),
    seed1 = s % 256,
    input_scale = noise.var("segmentation_multiplier") / scale,
    output_scale = amplitude / noise.var("segmentation_multiplier")
  })
end

local function basic_spot_noise(arguments)
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
  local elevation = noise.var("elevation")
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
  local elevation_favorability = noise.clamp(elevation, 0, 1)
  local center_favorability = noise.clamp(1 - distance_from_center / starting_region_size, 0, 1)
  local candidate_point_spacing = max_starting_spot_base_radius * 1.5

  function make_spot_radius_expression(richness_expression)
    return (kilo2_amount * richness_expression / resource_density) ^ (onethird)
  end

  local regular_spots = basic_spot_noise{
    seed = hash(seed),
    region_size =  kilo_amount * region_size_multiplier,
    maximum_spot_basement_radius = max_regular_spot_radius,

    density_expression = density_fixed_bias * density_multiplier * regular_placement_mask / enlarge_effect_expression, 
    spot_quantity_expression = kilo2_amount * random_expression, 
    spot_radius_expression = make_spot_radius_expression(regular_richness_expression * random_expression),
    spot_favorability_expression = elevation_favorability * regular_placement_mask,
  }

  local starting_spots = basic_spot_noise{
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
    spot_favorability_expression = elevation_favorability * center_favorability * starting_placement_mask,
  }

  local regular_patches = regular_spots
  local starting_patches = starting_spots
  if enabled_blobbiness then
    local starting_blob_expression = blob_noise(8, 1) + blob_noise(24, 1)
    local regular_blob_expression = starting_blob_expression + blob_noise(64, 1.5)
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
  local elevation = noise.var("elevation")
  local starting_area_radius = noise.var("kaizen_starting_area_radius")
  local enemy_base_density = noise.max(0, noise.var("enemy_base_density"))
  local enemy_base_size = noise.max(0, noise.var("enemy_base_size"))

  local density_multiplier = size_multiplier * frequency_multiplier * enemy_base_density_multiplier
  local enemy_base_radius = size_multiplier * enemy_base_size ^ onehalf
  local elevation_favorability = noise.clamp(elevation, 0, 1)

  local spots = basic_spot_noise{
    seed = hash"enemy-base",
    maximum_spot_basement_radius = max_enemy_base_radius,

    density_expression = enemy_base_density * density_multiplier,
    spot_quantity_expression = math.pi * onethird * enemy_base_radius ^ 2,
    spot_radius_expression = enemy_base_radius,
    spot_favorability_expression = elevation_favorability,
  }

  local blob_expression = blob_noise(8, 1) + blob_noise(24, 1) + blob_noise(64, 2)
  local base_patch = spots + blob_expression * spot_peek_height(spots) * blob_multiplier

  local enemy_base_placement_mask
  if discovery_level == 0 then
    enemy_base_placement_mask = noise.clamp(distance_from_center - starting_area_radius, 0, 1)
  elseif discovery_level == 1 then
    enemy_base_placement_mask = noise.clamp((distance_from_center - starting_area_radius) / first_level_radius, 0, 1)
  else
    local fade_in_distance = starting_area_radius + first_level_radius + discovery_level_base_radius * (discovery_level - 2)
    enemy_base_placement_mask = noise.clamp((distance_from_center - fade_in_distance) / discovery_level_base_radius, 0, 1)
  end

  local probability_expression = noise.delimit_procedure(base_patch)
  probability_expression = probability_expression * enemy_base_placement_mask * probability
  
  return
  {
    control = "enemy-base",
    order = order,
    force = "enemy",
    richness_expression = tne(1),
    probability_expression = probability_expression,
  }
end

data:extend{
  {
    type = "noise-expression",
    name = "kaizen_starting_area_radius",
    expression = noise.define_noise_function( function(x,y,tile,map)
      local starting_area_multiplier = noise.var("starting_area_radius") / 120
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
      local temperature = noise.var("temperature")
      local aux = noise.var("aux")
      return (1 + moisture * 6 + aux) / 8
    end)
  },
}

return {
  dump_expression = dump_expression,
  hash = hash,
  blob_noise = blob_noise,
  basic_spot_noise = basic_spot_noise,
  spot_peek_height = spot_peek_height,
  make_resource = make_resource,
  make_enemy_base = make_enemy_base,
  maked_resources = maked_resources,
}
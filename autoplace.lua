local noise = require("noise")
local expression_to_ascii_math = require("noise.expression-to-ascii-math")
local tne = noise.to_noise_expression
local litexp = noise.literal_expression

local base_multiplier = 1/40
local blob_multiplier = 1/8
local density_fixed_bias = 4

local first_level_radius = 32 * 3
local discovery_level_base_radius = 32 * 12
local enlarge_effect_distance = 32 * 12
local fade_in_range = 32 * 6
local max_regular_spot_radius = 128
local max_starting_spot_base_radius = 16

local max_starting_resources = 8
local kilo_amount = 1024
local kilo2_amount = kilo_amount * kilo_amount
local region_size_multiplier = 4
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

local function spot_peek_height(quantity, radius)
  if type(quantity) == "table" and quantity.function_name == "spot-noise" then
    local spot_noise = quantity
    quantity = spot_noise.arguments.spot_quantity_expression.literal_value
    radius = spot_noise.arguments.spot_radius_expression.literal_value
  end
  return 3 * quantity / (math.pi * radius^2)
end

local function make_resource(params)
  local control_name = params.control_name
  local seed = params.seed or control_name
  local order = params.order or "z"
  local discovery_level = params.discovery_level
  
  local starting_richness = params.starting_richness or 1
  local regular_richness = params.regular_richness or 1
  local additional_richness = params.additional_richness or 0
  local patch_count_per_kt2 = (params.patch_count_per_kt2 or 1)
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
  local moisture = noise.var("moisture")
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
    resource_index = nil
    starting_region_size = nil
    max_starting_spot_radius = 0
    starting_placement_mask = tne(0)
    regular_placement_mask = make_regular_placement_mask(0)
    enlarge_effect_expression = make_enlarge_effect_expression(0)
  end
  log(control_name..".resource_index = "..resource_index)
  log(control_name..".starting_placement_mask = "..starting_region_size)
  log(control_name..".max_starting_spot_radius = "..max_starting_spot_radius)
  dump_expression(control_name..".starting_placement_mask", starting_placement_mask)
  dump_expression(control_name..".regular_placement_mask", regular_placement_mask)
  dump_expression(control_name..".enlarge_effect_expression", enlarge_effect_expression)

  local regular_richness_expression = regular_richness * base_multiplier * size_multiplier * enlarge_effect_expression ^ 2
  local starting_richness_expression = starting_richness * base_multiplier * size_multiplier
  local density_multiplier = patch_count_per_kt2 * frequency_multiplier
  local elevation_favorability = noise.clamp(elevation, 0, 1)
  local center_favorability = noise.clamp(1 - distance_from_center / starting_region_size, 0, 1)

  function make_spot_radius_expression(richness_expression)
    return (kilo2_amount * richness_expression / resource_density) ^ (onethird)
  end

  local regular_spots = noise.function_application("spot-noise", {
    x = noise.var("x"),
    y = noise.var("y"),
    seed0 = noise.var("map_seed"),
    seed1 = hash(seed),
    region_size =  kilo_amount * region_size_multiplier,
    hard_region_target_quantity = false, 
    density_expression = litexp(density_fixed_bias * density_multiplier * regular_placement_mask / enlarge_effect_expression), 
    spot_quantity_expression = litexp(kilo2_amount * random_expression), 
    spot_radius_expression = litexp(make_spot_radius_expression(regular_richness_expression * random_expression)),
    spot_favorability_expression = litexp(elevation_favorability * regular_placement_mask),
    basement_value = -math.huge,
    maximum_spot_basement_radius = max_regular_spot_radius
  })

  local starting_spots = noise.function_application("spot-noise", {
    x = noise.var("x"),
    y = noise.var("y"),
    seed0 = noise.var("map_seed"),
    seed1 = hash"resource",
    region_size = starting_region_size * 2,
    skip_offset = resource_index,
    skip_span = max_starting_resources * (discovery_level + 1),
    candidate_point_count = math.min((starting_region_size * 2) ^ 2 / (max_starting_spot_base_radius * 2) ^ 2, 10000),
    minimum_candidate_point_spacing = max_starting_spot_base_radius * 2,
    hard_region_target_quantity = false,
    density_expression = litexp(density_multiplier * starting_placement_mask),
    spot_quantity_expression = litexp(kilo2_amount),
    spot_radius_expression = litexp(make_spot_radius_expression(starting_richness_expression)),
    spot_favorability_expression = litexp(elevation_favorability * center_favorability * starting_placement_mask),
    basement_value = -math.huge,
    maximum_spot_basement_radius = max_starting_spot_radius
  })

  local regular_patches = regular_spots
  local starting_patches = starting_spots
  if enabled_blobbiness then
    local starting_blob_expression = blob_noise(8, 1) + blob_noise(24, 1)
    local regular_blob_expression = starting_blob_expression + blob_noise(64, 1.5)
    regular_patches = regular_patches + regular_blob_expression * spot_peek_height(regular_spots) * blob_multiplier
    starting_patches = starting_patches + starting_blob_expression * spot_peek_height(starting_spots) * blob_multiplier
  end
  regular_patches = regular_patches * regular_richness_expression
  starting_patches = starting_patches * starting_richness_expression

  local all_patches
  if discovery_level then
    all_patches = noise.max(starting_patches, regular_patches)
  else
    all_patches = regular_patches
  end

  local richness_expression = noise.delimit_procedure(all_patches)
  local probability_expression = noise.clamp(richness_expression, 0, 1)

  local additional_richness_expression = additional_richness * base_multiplier * enlarge_effect_expression
  local additional_spot_area = math.pi * make_spot_radius_expression(regular_richness_expression) ^ 2
  richness_expression = richness_expression + kilo2_amount * additional_richness_expression / additional_spot_area
  richness_expression = richness_expression * richness_multiplier

  if tile_occurrence_probability < 1 then
    richness_expression = richness_expression / tile_occurrence_probability
    probability_expression = probability_expression * noise.random_penalty(1, 1 / tile_occurrence_probability) 
  end
  
  return {
    control = control_name,
    order = order,
    richness_expression = richness_expression,
    probability_expression = probability_expression,
  }
end

return {
  dump_expression = dump_expression,
  hash = hash,
  blob_noise = blob_noise,
  spot_peek_height = spot_peek_height,
  make_resource = make_resource,
}
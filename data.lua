local autoplace = require("autoplace")

data.raw["resource"]["iron-ore"].autoplace = autoplace.make_resource{
  control_name = "iron-ore",
  order = "b",
  discovery_level = 0,
  starting_richness = 20,
  regular_richness = 10,
}
data.raw["resource"]["copper-ore"].autoplace = autoplace.make_resource{
  control_name = "copper-ore",
  order = "b",
  discovery_level = 0,
  starting_richness = 10,
  regular_richness = 8,
}
data.raw["resource"]["coal"].autoplace = autoplace.make_resource{
  control_name = "coal",
  order = "b",
  discovery_level = 0,
  starting_richness = 10,
  regular_richness = 8,
}
data.raw["resource"]["stone"].autoplace = autoplace.make_resource{
  control_name = "stone",
  order = "b",
  discovery_level = 1,
  starting_richness = 4,
  regular_richness = 4,
  patch_count_per_kt2 = 1/2,
}
data.raw["resource"]["crude-oil"].autoplace = autoplace.make_resource{
  control_name = "crude-oil",
  order = "d",
  discovery_level = 2,
  starting_richness = 8,
  regular_richness = 8,
  additional_richness = 80,
  patch_count_per_kt2 = 1/2,
  patch_size_fluctuance = 0,
  tile_occurrence_probability = 1/36,
}
data.raw["resource"]["uranium-ore"].autoplace = autoplace.make_resource{
  control_name = "uranium-ore",
  order = "c",
  discovery_level = 3,
  resource_density = 100,
  patch_count_per_kt2 = 1/4,
  tile_occurrence_probability = 1/2,
}

data.raw["unit-spawner"]["biter-spawner"].autoplace = autoplace.make_enemy_base(0, "b-a", 1/60)
data.raw["unit-spawner"]["spitter-spawner"].autoplace = autoplace.make_enemy_base(0, "b-b", 1/60)
data.raw["turret"]["small-worm-turret"].autoplace = autoplace.make_enemy_base(1, "b-f", 1/120)
data.raw["turret"]["medium-worm-turret"].autoplace = autoplace.make_enemy_base(2, "b-e", 1/120)
data.raw["turret"]["big-worm-turret"].autoplace = autoplace.make_enemy_base(3, "b-d", 1/120)
data.raw["turret"]["behemoth-worm-turret"].autoplace = autoplace.make_enemy_base(4, "b-c", 1/120)

data.raw["map-gen-presets"]["default"]["death-world"].basic_settings.starting_area = 0.5
data.raw["map-gen-presets"]["default"]["death-world-marathon"].basic_settings.starting_area = 0.5
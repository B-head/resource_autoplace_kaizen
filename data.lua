local autoplace = require("autoplace");

data.raw["resource"]["iron-ore"].autoplace = autoplace.make_resource{
  control_name = "iron-ore",
  order = "b",
  discovery_level = 0,
  starting_richness = 15,
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
  starting_richness = 15,
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
  starting_richness = 10,
  regular_richness = 10,
  additional_richness = 200,
  patch_size_fluctuance = 0,
  tile_occurrence_probability = 1/20,
}
data.raw["resource"]["uranium-ore"].autoplace = autoplace.make_resource{
  control_name = "uranium-ore",
  order = "c",
  discovery_level = 3,
  resource_density = 100,
  patch_count_per_kt2 = 1/4,
}
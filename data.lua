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

data.raw["simple-entity"]["rock-huge"].autoplace = autoplace.make_rock("a-a-a", 1/200, 0.6, 1, 0, 1)
data.raw["simple-entity"]["rock-big"].autoplace = autoplace.make_rock("a-a-b", 1/100, 0.6, 1, 0, 1)
data.raw["simple-entity"]["sand-rock-big"].autoplace = autoplace.make_rock("a-a-c", 1/100, 0, 0.4, 0, 1)

data.raw["tree"]["tree-01"].autoplace = autoplace.make_tree("a-b-a", 1/3, 0.5, 1, 25, 35)
data.raw["tree"]["tree-02"].autoplace = autoplace.make_tree("a-b-b", 1/3, 0.55, 0.75, 10, 25)
data.raw["tree"]["tree-03"].autoplace = autoplace.make_tree("a-b-c", 1/3, 0.7, 0.9, 20, 30)
data.raw["tree"]["tree-04"].autoplace = autoplace.make_tree("a-b-d", 1/3, 0.4, 0.8, 5, 20)
data.raw["tree"]["tree-05"].autoplace = autoplace.make_tree("a-b-e", 1/3, 0.6, 1, 5, 20)
data.raw["tree"]["tree-09"].autoplace = autoplace.make_tree("a-b-f", 1/6, 0.3, 0.6, 25, 35)
data.raw["tree"]["tree-02-red"].autoplace = autoplace.make_tree("a-b-g", 1/3, 0.3, 0.6, 10, 25)
data.raw["tree"]["tree-07"].autoplace = autoplace.make_tree("a-b-h", 1/6, 0.15, 0.4, 15, 35)
data.raw["tree"]["tree-06"].autoplace = autoplace.make_tree("a-b-i", 1/6, 0.05, 0.3, 10, 35)
data.raw["tree"]["tree-06-brown"].autoplace = autoplace.make_tree("a-b-j", 1/6, 0.05, 0.3, 10, 35)
data.raw["tree"]["tree-09-brown"].autoplace = autoplace.make_tree("a-b-k", 1/6, 0.15, 0.4, 15, 35)
data.raw["tree"]["tree-09-red"].autoplace = autoplace.make_tree("a-b-l", 1/6, 0.15, 0.4, 5, 25)
data.raw["tree"]["tree-08"].autoplace = autoplace.make_tree("a-b-m", 1/6, 0, 0.3, 15, 25)
data.raw["tree"]["tree-08-brown"].autoplace = autoplace.make_tree("a-b-n", 1/6, 0, 0.3, 15, 25)
data.raw["tree"]["tree-08-red"].autoplace = autoplace.make_tree("a-b-o", 1/3, 0, 0.3, -5, 5)

data.raw["tree"]["dry-tree"].autoplace = autoplace.make_tree("a-c-a", 1/12, 0, 0.3, -5, 35)
data.raw["tree"]["dead-tree-desert"].autoplace = autoplace.make_tree("a-c-b", 1/12, 0, 0.3, -5, 35)
data.raw["tree"]["dead-grey-trunk"].autoplace = autoplace.make_tree("a-c-c", 1/6, 0, 0.3, -5, 35)
data.raw["tree"]["dead-dry-hairy-tree"].autoplace = autoplace.make_tree("a-c-d", 1/12, 0, 0.3, -5, 35)
data.raw["tree"]["dry-hairy-tree"].autoplace = autoplace.make_tree("a-c-e", 1/12, 0, 0.3, -5, 35)

data.raw["map-gen-presets"]["default"]["death-world"].basic_settings.starting_area = 0.5
data.raw["map-gen-presets"]["default"]["death-world-marathon"].basic_settings.starting_area = 0.5
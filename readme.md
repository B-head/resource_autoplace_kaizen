# Usage
```lua:usage
local autoplace = require("__resource_autoplace_kaizen__.autoplace")

-- Data definition.
data:extend({
    {
        type = "resource",
        name = "sulfur",

        autoplace = autoplace.make_resource{
          control_name = "sulfur",
          order = "b",
          discovery_level = 1,
          starting_richness = 4,
          regular_richness = 4,
          patch_count_per_kt2 = 1/2,
        },
        
        -- Other properties here.
    }
})

-- Data update.
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
```

## make_resource{} parameters
* control_name (required)
    * String identifier of autoplace control that applies to this entity.
* seed (default: use control_name parameter)
    * Seed value to pass to the noise function.
    * Specify number or string.
    * If specify the same value as other resources, the patch will be placed at the same position.
* order (default: "z")
    * Priority when overlapping with other resources.
* tile_restriction (default: {})
    * Restricts surfaces or transition the entity can appear on.
* discovery_level (default: nil)
    * Specify how far away from the center position there is the first patch.
    * Value of level 0, patches are placed at the center position.
    * Value of level 1, slightly away from the center position, but placed in the starting area.
    * Value of level 2, outside the starting area, but placed in the radar scan range.
    * By increasing the level further, can place the first patch further away.
    * Value of nil, although it is placed anywhere, there is no guarantee of the first patch position.
    * Value of true, This is the same as level 1.
    * Value of false, Placed outside the starting area, there is no guarantee of the first patch position.
* starting_richness (default: 1)
    * The amount of resources for patches first placed.
* regular_richness (default: 1)
    * The amount of resources for patches normally placed.
* additional_richness (default: 0)
    * The amount of resources added uniformly across the patch.
    * Used when to reduce the bias of the amount of resources per tile, like oil patch.
* patch_count_per_kt2 (default: 1)
    * The count of patches placed per 1024 \* 1024 tiles (32 \* 32 chunks).
* resource_density (default: 200)
    * Density of resources placed per tile.
    * Can control only the size without changing the amount of resources in the entire patch.
    * Recommended to reduce this value when defining a small amount of resources.
* patch_size_fluctuance (default: 1/2)
    * Range of randomly changing the patch size.
* tile_occurrence_probability (default: 1)
    * Probability of resources appearing in each tile.
    * Please be aware that if lower this number is too much the amount of resources will fluctuate greatly.
* enabled_blobbiness (default: true)
    * If set to true, the patch will be distorted by blob noise.

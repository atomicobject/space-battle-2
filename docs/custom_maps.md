# Custom Maps

You may want to test out edge cases or set up situations for testing that are not in the training maps.

Maps are built using [Tiled](http://www.mapeditor.org/). To build your own:

- Download and Install Tiled
- Copy an existing map
- Update layers
  - Blocked layer has cells filled in that are not walkable
  - Objects has resources and base starting locations (copying existing resources/bases will maintain needed type properties)
  - Environment has decorative tiles
- Export the map as JSON with Map -> Properties -> Tile Layer Format set to CSV

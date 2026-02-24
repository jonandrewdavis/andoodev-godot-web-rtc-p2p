# ![Tile Run Instances icon](documentation/tile_run_instances_icon.png) Tile Run Instances for Godot Game Engine
Tiles multiple instances of the game nicely across your monitor.
Helpful for testing multiplayer Godot games! Tested with Godot 4.0 and Godot 4.5.1.

![Nice tiling of multiple run instances.](documentation/sample_usage.gif)

## Features
- By default Godot stacks multiple game windows on top of each other. This addon lets you press play and instantly see all windows, lined up in a grid.
- Need your windows to show up on a different monitor? Edit the `target_monitor` variable of tile_run_instances_global.gd.

## Setup and Installation
1. Clone this repo
2. Copy tile-run-instances of this repo into the addons/ folder of your Godot project.
3. Under the Game tab, press the three dots and disable "Embed Game on Next Play".
![Disable Embed Game on Next Play.](documentation/disable_embedded_game_window.png)

4. Enable tile-run-instances in the Project Settings > Plugins tab.
![Enable the tile-run-instances plugin.](documentation/enable_plugin.png)

5. Add TileRunInstancesGlobal as a Global Autoload in Project Settings > Globals.
![Add TileRunInstancesGlobal as an autoload.](documentation/add_global_autoload.png)

6. Enable multiple instances in Debug > Customize Run Instances.
![Enable and add multiple instances.](documentation/customize_run_instances.png)


## Author
- Travh98 - Gamedev, Software Engineer. [🎮Itch.io page](https://travh98.itch.io/)

## Acknowledgments
- Inspired by Mr.Cdk's original tile-instances plugin.

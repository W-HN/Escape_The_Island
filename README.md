# GameLab-SW

Topdown:
- Town defence (NPC)
- Player is the Hero
- End goal: Escape the island? (in a boat?) one path to victory
- Multiple ways to reach the end goal ( Magic... )
- Player direction: 2 or 4
- Tech tree, experience points
- Skills
-  Some type of dungeon or cave (with monsters and rewards)
- Crafting
- Gems (Elemental) enhance weapons (sword and or bow) give to defender NPC
  
Must have features:
- 2D topdown 2 or 4 directions
- Day/Night cycle with more monsters at night 
- Town defence (night)
- Resource gathering (exp and skills) (Wood, stone)
- Island
	- End goal: Escape the island (Fix boat?)
- Crafting (items) with resources and monster drops
- Town upgrades with resources (wood and stone)

Starting point:
- Create character art


New first design 26/01/2024 (game loop)
- You need to fix the town's defence to defend against the monsters of the night.
	- Gather resources (wood and stone) and upgrade the town before the night falls.
- Kill monsters to gather gold.
	- Use gold to upgrade the player
 - When night falls, defend the town.
 - When morning comes, the towns defences is weakend + any damage from monsters.
 - Repeat the cycle the next day.

Second design 28/01/2024 (game loop)
- Game is split into 3 days, where each day ends by fixing the ship. (May add a fourth day where you escape)
  - Gather resources (wood and stone) to fix the ship and help the "town/settlement".
  - Days are "timegated" by adding more and more enemies each (minute?). This stops the player from farming everything on the first days.
- Monsters drop gold used, that can be used to upgrade the player. Maybe more...
- When morning comes, the towns defences is weakend + any damage from monsters.
- Repeat the cycle the next day.

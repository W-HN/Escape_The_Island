extends Area2D

signal water_entered

var direction

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass 


func _process(delta: float) -> void:
	pass

func _process_tilemap_collision(body: Node2D, body_rid: RID) -> void:
	pass

signal drown
func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	print("collision")
	if body is TileMapLayer:
		var tilemap = body as TileMapLayer

		var tile_coords = tilemap.local_to_map(global_position)
		var adjacent = tilemap.get_surrounding_cells(tile_coords)
		adjacent.append(tile_coords)
		for tile in adjacent:
			var cell_data = tilemap.get_cell_tile_data(tile)
			if cell_data:
				var is_water = cell_data.get_custom_data("is_water")
				if is_water:
					print("We hit a water tile!")
					#Signal to player
					emit_signal("drown")
					return

		

func _on_area_entered(area: Area2D) -> void:
	pass


func _on_player_player_direction(dir: Vector2) -> void:
	direction = dir

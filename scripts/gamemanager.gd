extends Node2D

@onready var multiplayer_ui = $CanvasLayer/MultiplayerUI

const player_scene = preload("res://scenes/player.tscn")
var peer = ENetMultiplayerPeer.new()

var players: Array[Player] = []

func _ready() -> void:
	$MultiplayerSpawner.spawn_function = add_player

func _on_host_pressed() -> void:
	multiplayer_ui.hide()
	peer.create_server(5170)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(
		func(pid):
			print(pid, " has joined the game")
			$MultiplayerSpawner.spawn(pid)
	)
	$MultiplayerSpawner.spawn((multiplayer.get_unique_id()))
	print("Host id: ",multiplayer.get_unique_id())
	

func _on_join_pressed() -> void:
	multiplayer_ui.hide()
	peer.create_client("localhost", 5170)
	multiplayer.multiplayer_peer = peer

func add_player(pid):
	var player = player_scene.instantiate()
	player.name = str(pid)
	player.global_position = $Island1.get_child(0).global_position
	players.append(player)
	
	return player

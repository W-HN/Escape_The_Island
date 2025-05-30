extends Node2D

const PLAYER = preload("res://scenes/player.tscn")

var peer = ENetMultiplayerPeer.new()

var players: Array = []

func _ready():
	$MultiplayerSpawner.spawn_function = add_player
	set_multiplayer_authority(1)

func _on_host_button_pressed() -> void:
	$MultiplayerUI.hide()
	peer.create_server(25565)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(
		func(pid):
			print("Peer " + str(pid) + " has joined the game")
			$MultiplayerSpawner.spawn(pid)
	)
	$MultiplayerSpawner.spawn(multiplayer.get_unique_id())

func _on_join_button_pressed() -> void:
	$MultiplayerUI.hide()
	peer.create_client("localhost", 25565)
	multiplayer.multiplayer_peer = peer

func add_player(pid):
	var player = PLAYER.instantiate()
	player.name = str(pid)
	player.global_position = $Island1.find_child("SpawnPoint").global_position
	players.append(player)
	
	return player
	

var gold: int = 0
var keys: int = 0

signal gold_changed(new_gold)
signal keys_changed(new_keys)

@rpc("any_peer")
func add_gold(amount: int):
	gold += amount
	emit_signal("gold_changed", gold)

@rpc("any_peer")
func add_key():
	keys += 1
	emit_signal("keys_changed", keys)

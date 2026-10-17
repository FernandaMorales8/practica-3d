# Marcador de un nivel. No construye nada: solo expone los datos que
# main.gd pide antes de generar la geometria con LevelBuilder.
#
# Cada escena de nivel lleva un nodo con este script y su level_index.
class_name LevelSource
extends Node3D

const DATA := preload("res://scripts/level_data.gd")

@export var level_index := 0


func get_level_data() -> Dictionary:
	var all := DATA.levels()
	if level_index < 0 or level_index >= all.size():
		push_error("level_index fuera de rango: %d" % level_index)
		return {}
	return all[level_index]

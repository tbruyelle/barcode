extends Node3D

var drawer_open: bool = false

@onready var drawer: Node3D = $Drawer

func toggle_drawer() -> void:
	var tween = create_tween()
	drawer_open = !drawer_open
	if drawer_open:
		tween.tween_property(drawer, "position:z", -0.2, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		tween.tween_property(drawer, "position:z", -0.04, 0.2).set_ease(Tween.EASE_IN)

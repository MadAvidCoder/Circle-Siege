extends Camera2D

func trigger_beat(delay):
	await get_tree().create_timer(delay).timeout
	var tween = get_tree().create_tween()
	tween.tween_property(self, "zoom", Vector2(1.05, 1.05), 0.07).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "zoom", Vector2(1, 1), 0.17).set_trans(Tween.TRANS_SINE)

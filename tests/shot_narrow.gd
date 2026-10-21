extends SceneTree
## Cruscotto su schermo stretto (telefono): immagine della scelta di marcia e carte.
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/home/claude/scratch/narrow_%s.png" % n)
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.splash_close.call()
	main.cfg["n"] = 4
	main.cfg["kind"] = [0, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2]
	main._start_race(main._local_game())
	while not main.dash.visible:
		await process_frame
	for i in 30: await process_frame
	await shot("piano")
	quit()

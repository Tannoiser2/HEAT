extends SceneTree
## Immagine ravvicinata delle 12 auto in griglia (controllo dei modelli e dei colori).
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/home/claude/scratch/cars_%s.png" % n)
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.splash_close.call()
	main.cfg["track"] = "usa"
	main.cfg["n"] = 12
	main.cfg["lx"] = 2
	main.cfg["kind"] = [0, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2]
	main.board.step_time = 0.5
	main._start_race(main._local_game())
	for i in 20: await process_frame
	main.board.follow = false
	main.board.focus(main.board.spot_pos(int(OS.get_environment("SP")) if OS.get_environment("SP") != "" else -3, 0), float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 7.0)
	for i in 60: await process_frame
	await shot("grid")
	quit()

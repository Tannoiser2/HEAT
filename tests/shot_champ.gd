extends SceneTree
## Fotografie: menu del campionato e classifica dopo la prima gara.
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/home/claude/scratch/ch_%s.png" % n)
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5: await process_frame
	main.splash_close.call()
	main.cfg["n"] = 6
	main.cfg["kind"] = [1, 1, 1, 1, 2, 2, 1, 1]
	main.cfg["mode"] = 1
	main.cfg["season"] = 3
	main._fill_setup()
	for i in 20: await process_frame
	await shot("0menu")
	main._start_champ(main._local_game())
	while main.racing:
		main.board.step_time = 0.002
		await create_timer(0.2).timeout
	for i in 20: await process_frame
	await shot("1classifica")
	quit()

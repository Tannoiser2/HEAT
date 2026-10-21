extends SceneTree
## Corsa automatica, poi replay: immagini di controllo durante il replay.
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/home/claude/scratch/replay_%s.png" % n)
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.splash_close.call()
	main.autoplay = true
	main.cfg["track"] = "gb"
	main.cfg["n"] = 6
	main.cfg["kind"] = [0, 1, 1, 1, 2, 2, 1, 1, 2, 2, 2, 2]
	main.cfg["laps"] = 1
	main._start_race(main._local_game())
	main.board.step_time = 0.002
	var t0 := Time.get_ticks_msec()
	while main.racing and Time.get_ticks_msec() - t0 < 200000:
		main.board.step_time = 0.002
		await create_timer(0.3).timeout
	await create_timer(0.5).timeout
	await shot("0risultati")
	print("storia: ", main.history.size(), " turni=", main.R.round)
	main._start_replay()
	await create_timer(2.4).timeout
	await shot("1turno1")
	await create_timer(5.0).timeout
	await shot("2turno4")
	main.replay["speed"] = 4.0
	await create_timer(12.0).timeout
	await shot("3fine")
	print("k=", main.replay["k"])
	main._end_replay()
	await create_timer(0.5).timeout
	await shot("4classifica")
	quit()

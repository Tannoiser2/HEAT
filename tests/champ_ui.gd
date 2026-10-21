extends SceneTree
## Campionato intero guidato dal computer, con l'interfaccia. SEASON=0..6
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5: await process_frame
	main.splash_close.call()
	main.autoplay = true
	main.cfg["n"] = 6
	main.cfg["kind"] = [0, 0, 1, 1, 2, 2, 1, 1]
	main.cfg["mode"] = 1
	main.cfg["season"] = int(OS.get_environment("SEASON")) if OS.get_environment("SEASON") != "" else 0
	main.cfg["pool"] = 2
	main.cfg["lx"] = int(OS.get_environment("LX")) if OS.get_environment("LX") != "" else 0
	main.cfg["riv"] = true
	main.cfg["lxup"] = true
	if main.cfg["lx"] > 0:
		main.cfg["n"] = 10
		main.cfg["kind"] = [0, 0, 1, 1, 2, 2, 1, 1, 2, 2, 2, 2]
	main._start_champ(main._local_game())
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		main.board.step_time = 0.002
		await create_timer(0.3).timeout
		if not main.racing:
			await create_timer(0.5).timeout
			var c: Dictionary = main.champ
			print("gara ", c["idx"] + 1, " ", c["events"][c["idx"]]["id"], " ", c["events"][c["idx"]]["t"], " turni=", main.R.round, " punti=", c["points"], " sponsor=", main.R.cars.map(func(x): return x["stats"].get("sponsor", 0)), " fuori=", main.R.out.size(), " lx=", main.R.lx_level, " rivali=", main.R.rivals)
			if c["idx"] + 1 >= c["events"].size():
				break
			for n in main.root.get_children():
				if n is PanelContainer and n != main.setup_box and n != main.panel and n != main.dash and n != main.lx_box:
					n.queue_free()
			c["idx"] += 1
			main._start_race(main._champ_race_game())
	print(main.log_box.get_parsed_text().right(600))
	quit()

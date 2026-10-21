extends SceneTree
## Due giochi completi (host e ospite) contro il finto Firebase: HEAT_ROLE=host oppure guest.
## Il codice della stanza passa per un file. Alla fine si stampano ordine d'arrivo e impronta dello stato.
func _init() -> void:
	var role := OS.get_environment("HEAT_ROLE")
	var code_file := OS.get_environment("HEAT_CODE_FILE")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.splash_close.call()
	for i in 5: await process_frame
	main.autoplay = OS.get_environment("HEAT_PHASE") != "manual"
	main.cfg["anim"] = 2
	main.board.step_time = 0.002
	main.online_name.text = "Stefano" if role == "host" else "Marco"
	main.online_box.visible = true
	if role == "host":
		main.cfg["n"] = 5
		main.cfg["kind"] = [0, 0, 1, 2, 2, 1, 1, 1]
		main.cfg["weather"] = true
		main.cfg["track"] = "japan"
		main.cfg["garage"] = int(OS.get_environment("GAR")) if OS.get_environment("GAR") != "" else 3
		if OS.get_environment("CHAMP") != "":
			main.cfg["mode"] = 1
			main.cfg["season"] = int(OS.get_environment("CHAMP"))
		await main._online_create()
		var code: String = main.online.get("code", "")
		print("host: stanza ", code)
		var f := FileAccess.open(code_file, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 30000:
			var room: Dictionary = await main.net.room(code)
			if Net._as_dict(room.get("seats", {})).size() >= 2:
				break
			await create_timer(0.5).timeout
		await main._online_start()
	else:
		var t0 := Time.get_ticks_msec()
		while not FileAccess.file_exists(code_file) and Time.get_ticks_msec() - t0 < 30000:
			await create_timer(0.3).timeout
		await create_timer(0.5).timeout
		var phase := OS.get_environment("HEAT_PHASE")
		if phase != "back" or main.online_code.text == "":
			main.online_code.text = FileAccess.get_file_as_string(code_file).strip_edges()
		await main._online_join()
		print("ospite: posto ", main.online.get("seat"), " ", main.online_lbl.text.replace("\n", " "))
		if phase == "drop":
			while main.R == null or main.R.round < 5:
				await process_frame
			print("ospite: esco al turno ", main.R.round)
			quit()
			return
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 900000:
		main.board.step_time = 0.002
		await create_timer(0.2).timeout
		if main.R != null and not main.racing:
			if main.champ.is_empty():
				break
			await create_timer(0.3).timeout
			var c: Dictionary = main.champ
			print(role, ": gara ", c["idx"] + 1, " punti=", c["points"], " impronta=", main.R.state_hash())
			if c["idx"] + 1 >= c["events"].size():
				break
			for n in main.root.get_children():
				if n is PanelContainer and n != main.setup_box and n != main.panel and n != main.dash and n != main.lx_box:
					n.queue_free()
			c["idx"] += 1
			main._start_race(main._champ_race_game())
	if main.R == null:
		print(role, ": la corsa non è partita. ", main.online_lbl.text)
	else:
		print(main.log_box.get_parsed_text().right(1500))
		print(role, ": racing=", main.racing, " conclusa=", main.R.all_finished(), " turni=", main.R.round, " ordine=", main.R.finished.map(func(c): return c["name"]), " impronta=", main.R.state_hash())
	quit()

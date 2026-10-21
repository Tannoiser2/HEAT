extends SceneTree
## Corse automatiche senza grafica: uso godot --headless --path . -s res://tests/sim.gd -- pista corse leggende meteo
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var key := args[0] if args.size() > 0 else "usa"
	var n := int(args[1]) if args.size() > 1 else 5
	var nleg := int(args[2]) if args.size() > 2 else 2
	var met := args.size() > 3 and args[3] == "1"
	var wins := {}
	var t0 := Time.get_ticks_msec()
	for k in n:
		var R := Rules.new()
		var cfg: Array = []
		for i in 4:
			cfg.append({"kind": "cpu", "col": i, "level": 1})
		for i in nleg:
			cfg.append({"kind": "legend", "col": 4 + i})
		R.setup(Track.by_key(key), cfg, {"seed": 1000 + k, "weather": met})
		while not R.all_finished() and R.round < 200:
			R.begin_round()
			if OS.get_environment("DBG") != "": print("round ", R.round, " ", R.cars.map(func(c): return c["s"]))
			for c in R.racing():
				if c["kind"] == "cpu":
					if not R.apply_plan(c, AI.plan(R, c)):
						push_error("piano non valido")
			for c in R.start_moves():
				if c["kind"] == "legend":
					R.legend_move(c)

					if c["s"] >= R.track.finish_s() and c["fin_round"] < 0:
						c["fin_round"] = R.round
					continue
				R.reveal(c)
				var t := {"r": [], "sl": false, "d": []}
				for a in AI.react(R, c):
					t["r"].append(a)
					if a == "a": R.adrenaline(c)
					else: R.boost(c)
				if AI.slip(R, c):
					t["sl"] = true
					R.slipstream(c)
				R.check_corners(c)
				var d := AI.discards(R, c)
				R.discard(c, d)
				R.end_turn(c)
			R.end_round()
			R.events.clear()
		var first: Dictionary = R.finished[0]
		wins[first["kind"]] = wins.get(first["kind"], 0) + 1
		var line := "corsa %d: %d turni |" % [k, R.round]
		for c in R.finished:
			line += " %s%s(c%d,sp%d,h%d)" % [c["kind"].substr(0, 1), c["col"], c["place"], c["stats"]["spin"], c["stats"]["heat"]]
		print(line)
	print("vittorie: ", wins, "  tempo ", Time.get_ticks_msec() - t0, " ms")
	quit()

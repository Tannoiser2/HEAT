extends SceneTree
## Confronto fra varianti del pilota automatico: quattro auto con moltiplicatori diversi del peso del Calore.
## Uso: -- corse m0 m1 m2 m3
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[0]) if a.size() > 0 else 40
	var muls: Array = []
	for k in 4:
		muls.append(float(a[k + 1]) if a.size() > k + 1 else 1.0)
	var keys := ["usa", "italia", "france", "gb", "japan", "mexico", "spagna", "nederland", "sudafrica", "germania"]
	var pts := [0.0, 0.0, 0.0, 0.0]
	var wins := [0, 0, 0, 0]
	var spins := [0, 0, 0, 0]
	var leg_beaten := 0
	for r in n:
		var R := Rules.new()
		var cfg: Array = []
		for i in 4:
			cfg.append({"kind": "cpu", "col": i, "level": int(OS.get_environment("LV").split(",")[i]) if OS.get_environment("LV") != "" else 1})
		cfg.append({"kind": "legend", "col": 4})
		cfg.append({"kind": "legend", "col": 5})
		R.setup(Track.by_key(keys[r % keys.size()]), cfg, {"seed": 500 + r, "weather": r % 2 == 0, "garage": int(OS.get_environment("GAR")) if OS.get_environment("GAR") != "" else 0})
		for i in 4:
			R.cars[(i + r) % 4]["wmul"] = muls[i]
			R.cars[(i + r) % 4]["level"] = int(OS.get_environment("LV").split(",")[i]) if OS.get_environment("LV") != "" else 1
		while R.drafting():
			for c in R.draft_order():
				if R.needs_pick(c):
					R.draft_pick(c, AI.draft_pick(R, c))
			R.draft_advance()
		while not R.all_finished() and R.round < 200:
			R.begin_round()
			for c in R.racing():
				if c["kind"] == "cpu":
					R.apply_plan(c, AI.plan(R, c))
			for c in R.start_moves():
				if c["kind"] == "legend":
					R.legend_move(c)
					R.end_turn(c)
					continue
				R.reveal_flip(c)
				R.reveal_move(c, AI.choices(R, c))
				for x in AI.react(R, c):
					R.do_action(c, x)
				for x in AI.react_late(R, c):
					R.do_action(c, x)
				while AI.slip(R, c):
					R.slipstream(c)
				R.check_corners(c)
				R.discard(c, AI.discards(R, c))
				R.end_turn(c)
			R.end_round()
			R.events.clear()
		for c in R.finished:
			if c["kind"] == "cpu":
				var vi: int = muls.find(c["wmul"]) if muls.count(c["wmul"]) == 1 else (c["i"] - r % 4 + 4) % 4
				pts[vi] += [9, 6, 4, 3, 2, 1][c["place"] - 1]
				if c["place"] == 1:
					wins[vi] += 1
				spins[vi] += c["stats"]["spin"]
		if R.finished[0]["kind"] == "cpu":
			leg_beaten += 1
	print("moltiplicatori ", muls, " punti ", pts, " vittorie ", wins, " testacoda ", spins, " | CPU vince ", leg_beaten, "/", n)
	quit()

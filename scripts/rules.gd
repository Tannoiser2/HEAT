## Regole di HEAT: Pedal to the Metal (gioco base, Leggende, meteo e condizioni della strada,
## caratteristiche delle piste delle espansioni). Nessuna interfaccia: solo stato e passi del turno.
## Tutto è deterministico a partire dal seme: ogni auto mescola il suo mazzo con un suo generatore,
## così online basta scambiarsi le scelte dei giocatori.
class_name Rules
extends RefCounted

const COLOR_KEYS := ["rosso", "blu", "giallo", "grigio", "verde", "nero", "viola", "arancio"]
const COLOR_NAMES := ["Rossa", "Blu", "Gialla", "Argento", "Verde", "Nera", "Viola", "Arancione"]
const COLORS := [Color("#D8312B"), Color("#2C64C8"), Color("#F2C42C"), Color("#B9BEC4"), Color("#2E9C4E"), Color("#2A2A2E"), Color("#9B3FC4"), Color("#EE7A22")]
const NUMBERS := [7, 2, 5, 11, 3, 9, 8, 4]
const LEGEND_COLORS := [0, 1, 2, 3, 4, 5]      # le carte Leggenda del gioco base hanno questi sei colori
const HAND := 7

## Carte Leggenda del gioco base: per colore [velocità massima (casco), rombo].
const LEGEND_CARDS := [
	{"rosso": [11, 0], "verde": [10, 0], "grigio": [13, 1], "blu": [14, 1], "giallo": [15, 2], "nero": [17, 2]},
	{"blu": [10, 0], "verde": [13, 1], "giallo": [12, 1], "rosso": [14, 1], "nero": [19, 3], "grigio": [18, 3]},
	{"giallo": [11, 0], "rosso": [13, 1], "grigio": [14, 1], "verde": [15, 2], "nero": [16, 2], "blu": [18, 3]},
	{"grigio": [11, 0], "blu": [13, 1], "giallo": [14, 1], "nero": [15, 2], "verde": [19, 3], "rosso": [18, 3]},
	{"nero": [14, 1], "blu": [12, 1], "rosso": [15, 2], "grigio": [16, 2], "giallo": [17, 2], "verde": [18, 3]},
	{"giallo": [13, 1], "verde": [12, 1], "rosso": [17, 2], "blu": [16, 2], "grigio": [19, 3], "nero": [18, 3]},
	{"rosso": [10, 0], "nero": [13, 1], "grigio": [12, 1], "blu": [17, 2], "verde": [16, 2], "giallo": [19, 3]},
	{"verde": [11, 0], "nero": [10, 0], "blu": [15, 2], "rosso": [16, 2], "grigio": [17, 2], "giallo": [18, 3]},
	{"nero": [11, 0], "grigio": [10, 0], "verde": [14, 1], "rosso": [12, 1], "giallo": [16, 2], "blu": [19, 3]},
	{"blu": [11, 0], "giallo": [10, 0], "nero": [12, 1], "grigio": [15, 2], "verde": [17, 2], "rosso": [19, 3]},
]

## Gettoni Meteo: preparazione dell'auto e effetto nei settori con il gettone "meteo".
const WEATHER := [
	{"name": "Nuvoloso", "setup": "stress-1", "fx": "nocool", "txt": "una carta Stress in meno; nei settori meteo niente raffreddamento"},
	{"name": "Gelo", "setup": "heat-1", "fx": "cool", "txt": "un Calore in meno nel motore; nei settori meteo +1 raffreddamento"},
	{"name": "Pioggia", "setup": "heat3deck", "fx": "cool", "txt": "3 Calore mescolati nel mazzo; nei settori meteo +1 raffreddamento"},
	{"name": "Sole", "setup": "heat3discard", "fx": "slip2", "txt": "3 Calore negli scarti; nei settori meteo scia +2"},
	{"name": "Vento", "setup": "stress+1", "fx": "slip2", "txt": "una carta Stress in più; nei settori meteo scia +2"},
	{"name": "Acquazzone", "setup": "heat+1", "fx": "noslip", "txt": "un Calore in più nel motore; nei settori meteo niente scia"},
]
## Gettoni Condizioni della strada (due copie ciascuno): i primi tre valgono per la curva, gli altri per il settore.
const ROAD := [
	{"k": "over", "name": "Surriscaldamento", "corner": true, "txt": "chi supera il limite paga 1 Calore in più"},
	{"k": "lim+", "name": "Limite +1", "corner": true, "txt": "limite di velocità +1"},
	{"k": "lim-", "name": "Limite -1", "corner": true, "txt": "limite di velocità -1"},
	{"k": "free", "name": "Spinta gratuita", "corner": false, "txt": "nel settore la spinta non costa Calore"},
	{"k": "meteo", "name": "Meteo", "corner": false, "txt": "nel settore vale l'effetto del meteo"},
	{"k": "slip", "name": "Scia +1", "corner": false, "txt": "nel settore la scia fa 1 casella in più"},
]

var track: Track
var cars: Array = []
var round := 0
var seed := 1
var rng := RandomNumberGenerator.new()
var weather := -1          # indice in WEATHER, -1 senza meteo
var road := {}             # gruppo di curve -> indice in ROAD
var legend_deck: Array = []
var legend_card := -1      # carta Leggenda del turno (-1 non ancora girata)
var legend_pro := 0
var chevrons := true
var adr_n := 1
var order: Array = []      # ordine di movimento del turno in corso
var adr_set: Array = []
var finished: Array = []   # auto arrivate, in ordine
var events: Array = []     # eventi per animazioni e cronaca, svuotati da chi li legge
var started := 0

# ---------- preparazione ----------

## cfg: [{kind: "human"/"cpu"/"legend", col, name}]; opts: {seed, weather(bool), legend_pro, chevrons, grid: Array opzionale}
func setup(t: Track, cfg: Array, opts: Dictionary) -> void:
	track = t
	seed = int(opts.get("seed", 1))
	rng.seed = seed
	legend_pro = int(opts.get("legend_pro", 0))
	chevrons = bool(opts.get("chevrons", true))
	cars.clear()
	finished.clear()
	round = 0
	for i in cfg.size():
		var c: Dictionary = cfg[i]
		var car := {"i": i, "col": int(c["col"]), "name": str(c.get("name", COLOR_NAMES[int(c["col"])])), "kind": str(c["kind"]),
			"s": 0, "lane": 0, "gear": 1, "deck": [], "hand": [], "discard": [], "play": [], "engine": 0,
			"fin": false, "fin_round": -1, "place": 0, "level": int(c.get("level", 1)),
			"rng": RandomNumberGenerator.new(), "stats": {"heat": 0, "spin": 0, "boost": 0, "slip": 0}}
		car["rng"].seed = seed * 7919 + i * 104729 + 13
		cars.append(car)
	started = cars.size()
	adr_n = 2 if started >= 5 else 1
	# meteo e condizioni della strada
	weather = -1
	road = {}
	if opts.get("weather", false):
		weather = rng.randi_range(0, WEATHER.size() - 1)
		var bag: Array = []
		for k in ROAD.size():
			bag.append(k)
			bag.append(k)
		_shuffle(bag, rng)
		for g in track.groups.size():
			road[g] = bag[g % bag.size()]
	# griglia di partenza casuale (o data)
	var grid: Array = opts.get("grid", [])
	if grid.size() != cars.size():
		grid = range(cars.size())
		_shuffle(grid, rng)
	for p in grid.size():
		var car: Dictionary = cars[int(grid[p])]
		car["s"] = -1 - p / 2
		car["lane"] = p % 2
		car["grid"] = p + 1
	# mazzi
	for car in cars:
		if car["kind"] == "legend":
			continue
		var heat := track.heat
		var stress := track.stress
		var deck: Array = []
		for v in [1, 2, 3, 4]:
			for k in 3:
				deck.append({"t": "s", "v": v})
		deck.append({"t": "u", "v": 0})
		deck.append({"t": "u", "v": 5})
		deck.append({"t": "h", "v": 0, "u": true})
		var to_discard := 0
		if weather >= 0:
			match WEATHER[weather]["setup"]:
				"stress-1": stress -= 1
				"stress+1": stress += 1
				"heat-1": heat -= 1
				"heat+1": heat += 1
				"heat3deck":
					heat -= 3
					for k in 3:
						deck.append({"t": "h", "v": 0})
				"heat3discard":
					heat -= 3
					to_discard = 3
		for k in stress:
			deck.append({"t": "x", "v": 0})
		_shuffle(deck, car["rng"])
		car["deck"] = deck
		car["engine"] = maxi(heat, 0)
		for k in to_discard:
			car["discard"].append({"t": "h", "v": 0})
		_draw(car)
	# Leggende
	legend_deck = range(LEGEND_CARDS.size())
	_shuffle(legend_deck, rng)

static func _shuffle(a: Array, g: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := g.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp

# ---------- utilità ----------

func racing() -> Array:
	return cars.filter(func(c): return not c["fin"])

func humans() -> Array:
	return cars.filter(func(c): return c["kind"] == "human")

func is_legend(car: Dictionary) -> bool:
	return car["kind"] == "legend"

func all_finished() -> bool:
	return racing().is_empty()

## Ordine di gara: dalla più avanti; a parità di casella prima quella sulla linea ideale.
func race_order() -> Array:
	var a := racing()
	a.sort_custom(func(x, y): return x["s"] > y["s"] or (x["s"] == y["s"] and x["lane"] < y["lane"]))
	return a

## Classifica attuale (arrivate prima, poi in gara).
func standings() -> Array:
	var out: Array = finished.duplicate()
	out.append_array(race_order())
	return out

func occupied_lanes(s: int, except = null) -> Array:
	var out: Array = []
	var ix := track.idx(s)
	for c in cars:
		if c["fin"] or c == except:
			continue
		if track.idx(c["s"]) == ix:
			out.append(c["lane"])
	return out

## Posto libero più avanti possibile, partendo da target e tornando indietro fino a min_s (dove resta l'auto stessa).
func _place(car: Dictionary, target: int, min_s: int) -> void:
	var t := target
	while t > min_s:
		var occ := occupied_lanes(t, car)
		if occ.size() < 2:
			car["s"] = t
			car["lane"] = 0 if not occ.has(0) else 1
			return
		t -= 1
	# nessun posto libero: resta dov'è (oppure, se min_s è un'altra casella, il primo posto libero all'indietro)
	if min_s != car["s"]:
		t = min_s
		while true:
			var occ2 := occupied_lanes(t, car)
			if occ2.size() < 2:
				car["s"] = t
				car["lane"] = 0 if not occ2.has(0) else 1
				return
			t -= 1

func _move(car: Dictionary, amount: int, why: String) -> void:
	var s0: int = car["s"]
	var l0: int = car["lane"]
	_place(car, s0 + amount, s0)
	events.append({"e": "move", "car": car["i"], "from": s0, "lane0": l0, "to": car["s"], "lane": car["lane"], "why": why, "want": s0 + amount})

func _flip(car: Dictionary) -> Dictionary:
	if car["deck"].is_empty():
		_reshuffle(car)
	if car["deck"].is_empty():
		return {}
	return car["deck"].pop_back()

func _reshuffle(car: Dictionary) -> void:
	if car["discard"].is_empty():
		return
	car["deck"] = car["discard"]
	car["discard"] = []
	_shuffle(car["deck"], car["rng"])
	events.append({"e": "shuffle", "car": car["i"]})

func _draw(car: Dictionary) -> void:
	while car["hand"].size() < HAND:
		var c := _flip(car)
		if c.is_empty():
			break
		car["hand"].append(c)

## Gira carte dal mazzo finché esce una carta base (1-4): le altre vanno negli scarti. Restituisce il valore.
func _flip_basic(car: Dictionary) -> int:
	var guard := 0
	while guard < 200:
		guard += 1
		var c := _flip(car)
		if c.is_empty():
			return 0
		if c["t"] == "s":
			c["flip"] = true
			car["play"].append(c)
			return int(c["v"])
		car["discard"].append(c)
	return 0

func _pay_heat(car: Dictionary, n: int) -> int:
	var paid := mini(n, int(car["engine"]))
	car["engine"] -= paid
	for k in paid:
		car["discard"].append({"t": "h", "v": 0})
	car["stats"]["heat"] += paid
	return paid

static func playable(c: Dictionary) -> bool:
	return c["t"] != "h"

static func card_value(c: Dictionary) -> int:
	return int(c["v"]) if c["t"] == "s" or c["t"] == "u" else 0

func playable_count(car: Dictionary) -> int:
	return car["hand"].filter(func(c): return playable(c)).size()

func heat_in_hand(car: Dictionary) -> int:
	return car["hand"].filter(func(c): return c["t"] == "h").size()

## Velocità del turno (carte giocate + adrenalina), quella che conta per le curve.
func speed(car: Dictionary) -> int:
	var v := 0
	for c in car["play"]:
		v += card_value(c)
	return v + (1 if car.get("adr_used", false) else 0)

func flooded(car: Dictionary) -> bool:
	return track.space(car["s"]).has("flood")

func in_tunnel(car: Dictionary) -> bool:
	return track.space(car["s"]).has("tunnel")

func on_gravel(car: Dictionary) -> bool:
	var sp := track.space(car["s"])
	return sp.has("gravel") and int(sp["gravel"][car["lane"]]) == 1

## Effetto del settore in cui si trova l'auto: "free", "slip", oppure l'effetto meteo ("cool", "nocool", "slip2", "noslip").
func sector_fx(car: Dictionary) -> Array:
	var out: Array = []
	if road.is_empty():
		return out
	var g := track.sector_of(car["s"])
	var tok: Dictionary = ROAD[road.get(g, 0)]
	if tok["corner"]:
		return out
	if tok["k"] == "meteo":
		if weather >= 0:
			out.append(WEATHER[weather]["fx"])
	else:
		out.append(tok["k"])
	return out

func corner_limit(k: int) -> int:
	var lim: int = track.corners[k]["lim"]
	if not road.is_empty():
		var tok: Dictionary = ROAD[road.get(track.corners[k]["group"], 0)]
		if tok["k"] == "lim+":
			lim += 1
		elif tok["k"] == "lim-":
			lim -= 1
	return lim

func corner_over(k: int) -> int:
	if road.is_empty():
		return 0
	return 1 if ROAD[road.get(track.corners[k]["group"], 0)]["k"] == "over" else 0

## Costo in Calore per cambiare marcia (0 se non si può).
func shift_cost(car: Dictionary, g: int) -> int:
	var d: int = g - int(car["gear"])
	if absi(d) > 2 or g < 1 or g > 4:
		return 99
	var cost := 1 if absi(d) == 2 else 0
	if d < 0 and flooded(car):
		cost += 1
	return cost

# ---------- turno ----------

func begin_round() -> void:
	round += 1
	legend_card = -1
	for c in racing():
		c["play"] = []
		c["adr_used"] = false
		c["boosted"] = false
		c["slipped"] = false
		c["spun"] = false
		c["clutter"] = false
		c["turn_done"] = false
		c["plan_done"] = c["kind"] == "legend"

## Fase 1-2: marcia e carte. plan = {g: marcia, c: [indici nella mano]}. Restituisce false se non valido.
func apply_plan(car: Dictionary, plan: Dictionary) -> bool:
	var g := int(plan.get("g", car["gear"]))
	var cost := shift_cost(car, g)
	if cost > car["engine"]:
		return false
	var idxs: Array = []
	for x in plan.get("c", []):
		idxs.append(int(x))
	idxs.sort()
	for x in idxs:
		if x < 0 or x >= car["hand"].size():
			return false
	if cost > 0:
		_pay_heat(car, cost)
		events.append({"e": "shift_heat", "car": car["i"], "n": cost})
	var g0: int = car["gear"]
	car["gear"] = g
	var chosen: Array = []
	for k in range(idxs.size() - 1, -1, -1):
		chosen.append(car["hand"][idxs[k]])
		car["hand"].remove_at(idxs[k])
	chosen.reverse()
	var n_play := chosen.filter(func(c): return playable(c)).size()
	if n_play < g:
		# mano intasata: si copre la differenza con carte Calore e l'auto non si muove
		car["clutter"] = true
		var need := g - n_play
		var i: int = car["hand"].size() - 1
		while need > 0 and i >= 0:
			if car["hand"][i]["t"] == "h":
				chosen.append(car["hand"][i])
				car["hand"].remove_at(i)
				need -= 1
			i -= 1
	car["play"] = chosen
	car["plan_done"] = true
	if g != g0:
		events.append({"e": "gear", "car": car["i"], "from": g0, "to": g})
	return true

## Piano valido? (per l'interfaccia): {ok, msg}
func check_plan(car: Dictionary, g: int, idxs: Array) -> Dictionary:
	var cost := shift_cost(car, g)
	if cost == 99:
		return {"ok": false, "msg": "Si può cambiare al massimo di due marce."}
	if cost > car["engine"]:
		return {"ok": false, "msg": "Non hai abbastanza Calore nel motore per questo cambio."}
	var n_play := playable_count(car)
	if idxs.size() != mini(g, n_play):
		return {"ok": false, "msg": "In %da marcia si giocano %d carte." % [g, g] if n_play >= g else "Mano intasata: gioca tutte le %d carte giocabili." % n_play}
	for x in idxs:
		if not playable(car["hand"][int(x)]):
			return {"ok": false, "msg": "Le carte Calore non si possono giocare."}
	return {"ok": true, "msg": ""}

## Ordine di movimento del turno e chi ha diritto all'adrenalina.
func start_moves() -> Array:
	order = race_order()
	adr_set = []
	for k in mini(adr_n, order.size()):
		adr_set.append(order[order.size() - 1 - k]["i"])
	return order

func has_adrenaline(car: Dictionary) -> bool:
	return adr_set.has(car["i"]) and not is_legend(car)

## Fase 3: girare le carte e muovere. Restituisce la velocità.
func reveal(car: Dictionary) -> int:
	car["s0"] = car["s"]
	car["lane_0"] = car["lane"]
	if car["clutter"]:
		events.append({"e": "clutter", "car": car["i"]})
		car["gear"] = 1
		for c in car["play"]:
			car["discard"].append(c)
		car["play"] = []
		return 0
	var flips: Array = []
	for c in car["play"].duplicate():
		if c["t"] == "x":
			flips.append(_flip_basic(car))
	var v0 := speed(car)
	events.append({"e": "reveal", "car": car["i"], "speed": v0})
	for v in flips:
		events.append({"e": "stress", "car": car["i"], "v": v})
	_move(car, v0, "carte")
	# raffreddamento automatico (marcia, adrenalina, meteo): sempre conveniente farlo subito
	_cooldown(car)
	return v0

func _cooldown(car: Dictionary) -> void:
	var fx := sector_fx(car)
	var cool := 3 if car["gear"] == 1 else (1 if car["gear"] == 2 else 0)
	if has_adrenaline(car):
		cool += 1
	if fx.has("cool"):
		cool += 1
	if fx.has("nocool"):
		cool = 0
	var n := 0
	while n < cool:
		var found := -1
		for k in car["hand"].size():
			if car["hand"][k]["t"] == "h":
				found = k
				break
		if found < 0:
			break
		car["hand"].remove_at(found)
		car["engine"] += 1
		n += 1
	if n > 0:
		events.append({"e": "cool", "car": car["i"], "n": n})

func can_boost(car: Dictionary) -> bool:
	if car["clutter"] or car["boosted"] or car["fin_round"] >= 0:
		return false
	return car["engine"] > 0 or sector_fx(car).has("free")

## Spinta: paga 1 Calore (gratis nei settori "free") e gira carte fino a una carta base.
func boost(car: Dictionary) -> int:
	if not can_boost(car):
		return 0
	car["boosted"] = true
	if not sector_fx(car).has("free"):
		_pay_heat(car, 1)
	var v := _flip_basic(car)
	car["stats"]["boost"] += 1
	events.append({"e": "boost", "car": car["i"], "v": v})
	_move(car, v, "spinta")
	return v

func can_adrenaline(car: Dictionary) -> bool:
	return has_adrenaline(car) and not car["adr_used"] and not car["clutter"] and car["fin_round"] < 0

func adrenaline(car: Dictionary) -> void:
	if not can_adrenaline(car):
		return
	car["adr_used"] = true
	events.append({"e": "adrenaline", "car": car["i"]})
	_move(car, 1, "adrenalina")

## Scia: possibile accanto a un'auto o nella casella subito dietro. Restituisce le caselle (0 se non possibile).
func slip_amount(car: Dictionary) -> int:
	if car["clutter"] or car["slipped"] or car["fin_round"] >= 0:
		return 0
	var fx := sector_fx(car)
	if fx.has("noslip"):
		return 0
	var s: int = car["s"]
	var near := false
	for c in cars:
		if c == car or c["fin"]:
			continue
		var d := track.idx(c["s"] - s)
		if d == 0 or d == 1:
			near = true
			break
	if not near:
		return 0
	var amt := 2
	if fx.has("slip"):
		amt += 1
	if fx.has("slip2"):
		amt += 2
	# la scia non può far tagliare il traguardo finale
	if s + amt >= track.finish_s():
		return 0
	return amt

func slipstream(car: Dictionary) -> void:
	var amt := slip_amount(car)
	if amt <= 0:
		return
	car["slipped"] = true
	car["stats"]["slip"] += 1
	events.append({"e": "slip", "car": car["i"], "n": amt})
	_move(car, amt, "scia")

## Calore che costerebbero le curve attraversate da s0 a s1 con la velocità v (99 = testacoda).
func corner_cost(car: Dictionary, s0: int, s1: int, v: int) -> int:
	var tot := 0
	for x in track.crossed(s0, s1):
		if x["b"] > track.finish_s():
			continue
		var ex := v - corner_limit(x["k"])
		if ex > 0:
			tot += ex + corner_over(x["k"])
	return tot

## Fase 7: controllo delle curve attraversate in questo turno.
func check_corners(car: Dictionary) -> void:
	if car["clutter"]:
		return
	var v := speed(car)
	for x in track.crossed(car["s0"], car["s"]):
		if x["b"] > track.finish_s():
			continue
		var k: int = x["k"]
		var lim := corner_limit(k)
		var ex := v - lim
		if ex <= 0:
			events.append({"e": "corner_ok", "car": car["i"], "k": k, "v": v, "lim": lim})
			continue
		var cost := ex + corner_over(k)
		if car["engine"] >= cost:
			_pay_heat(car, cost)
			events.append({"e": "corner_heat", "car": car["i"], "k": k, "v": v, "lim": lim, "n": cost})
			continue
		# testacoda
		var paid := _pay_heat(car, cost)
		var s_from: int = car["s"]
		var l_from: int = car["lane"]
		var back: int = x["b"] - 1
		var t := back
		while occupied_lanes(t, car).size() >= 2:
			t -= 1
		car["s"] = t
		var occ := occupied_lanes(t, car)
		car["lane"] = 0 if not occ.has(0) else 1
		var n_stress := 1 if car["gear"] <= 2 else 2
		for j in n_stress:
			car["hand"].append({"t": "x", "v": 0})
		car["gear"] = 1
		car["spun"] = true
		car["stats"]["spin"] += 1
		events.append({"e": "spin", "car": car["i"], "k": k, "v": v, "lim": lim, "paid": paid, "stress": n_stress,
			"from": s_from, "lane0": l_from, "to": car["s"], "lane": car["lane"]})
		break

func can_discard(car: Dictionary) -> bool:
	return not in_tunnel(car)

static func discardable(c: Dictionary) -> bool:
	return c["t"] == "s" or c["t"] == "u"

## Fase 8: scarta le carte indicate (indici nella mano).
func discard(car: Dictionary, idxs: Array) -> void:
	if idxs.is_empty() or not can_discard(car):
		return
	var a: Array = []
	for x in idxs:
		a.append(int(x))
	a.sort()
	var n := 0
	for k in range(a.size() - 1, -1, -1):
		var x: int = a[k]
		if x >= 0 and x < car["hand"].size() and discardable(car["hand"][x]):
			car["discard"].append(car["hand"][x])
			car["hand"].remove_at(x)
			n += 1
	if n > 0:
		events.append({"e": "discard", "car": car["i"], "n": n})

## Fase 9: fine turno dell'auto: carte giocate negli scarti, ghiaia, si pesca fino a 7.
func end_turn(car: Dictionary) -> void:
	for c in car["play"]:
		var cc: Dictionary = c.duplicate()
		cc.erase("flip")
		car["discard"].append(cc)
	car["play"] = []
	if on_gravel(car) and car["engine"] > 0:
		_pay_heat(car, 1)
		events.append({"e": "gravel", "car": car["i"]})
	_draw(car)
	car["turn_done"] = true
	if car["s"] >= track.finish_s() and car["fin_round"] < 0:
		car["fin_round"] = round
		events.append({"e": "cross", "car": car["i"]})

## Il resto del turno di un'auto dopo aver girato le carte, a partire dalle scelte:
## turn = {r: ["a","b"] nell'ordine scelto, sl: bool, d: [indici da scartare]}
func apply_turn(car: Dictionary, turn: Dictionary) -> void:
	for a in turn.get("r", []):
		if a == "a":
			adrenaline(car)
		elif a == "b":
			boost(car)
	if turn.get("sl", false):
		slipstream(car)
	check_corners(car)
	discard(car, turn.get("d", []))
	end_turn(car)

# ---------- Leggende ----------

func flip_legend_card() -> int:
	if legend_card < 0:
		if legend_deck.is_empty():
			legend_deck = range(LEGEND_CARDS.size())
			_shuffle(legend_deck, rng)
		legend_card = legend_deck.pop_back()
		events.append({"e": "legend_card", "card": legend_card})
	return legend_card

func legend_values(car: Dictionary) -> Array:
	var card: Dictionary = LEGEND_CARDS[flip_legend_card()]
	var key: String = COLOR_KEYS[car["col"]]
	var v: Array = card.get(key, [12, 1])
	return [int(v[0]) + legend_pro, int(v[1])]

## Una Leggenda oltre la linea delle Leggende affronta la curva (limite + rombo), altrimenti si avvicina.
func legend_move(car: Dictionary) -> void:
	car["s0"] = car["s"]
	var vals := legend_values(car)
	var top: int = vals[0]
	var dia: int = vals[1]
	var s: int = car["s"]
	var nc := track.next_corner(s)
	var k: int = nc["k"]
	var b: int = nc["b"]
	var c_idx: int = track.corners[k]["c"]
	var lb: int = track.corners[k]["legend"]
	var past := posmod(track.idx(s) - (lb + 1), track.n) <= posmod(c_idx - (lb + 1), track.n)
	var target := s
	if past:
		var extra := int(track.space(s).get("chev", 0)) if chevrons else 0
		target = s + corner_limit(k) + dia
		var lines := track.crossed(s, target)
		if lines.size() > 1 + extra:
			target = int(lines[1 + extra]["b"]) - 1
	else:
		if s + top < b:
			target = s + top
		else:
			target = maxi(s, b - 1 - dia)
	events.append({"e": "legend", "car": car["i"], "top": top, "dia": dia, "past": past})
	_move(car, target - s, "leggenda")

# ---------- fine turno ----------

## Chi ha tagliato il traguardo in questo turno esce dalla pista e prende il suo posto in classifica.
func end_round() -> Array:
	var arrived := cars.filter(func(c): return not c["fin"] and c["fin_round"] == round)
	arrived.sort_custom(func(x, y): return x["s"] > y["s"] or (x["s"] == y["s"] and x["lane"] < y["lane"]))
	for c in arrived:
		c["fin"] = true
		finished.append(c)
		c["place"] = finished.size()
	return arrived

# ---------- stato per il gioco online ----------

## Fotografia dello stato (per annullare un turno giocato in locale se online vale quello già pubblicato).
func snapshot() -> Dictionary:
	var cs: Array = []
	for c in cars:
		var d: Dictionary = {}
		for k in c:
			if k == "rng":
				continue
			d[k] = c[k].duplicate(true) if c[k] is Array or c[k] is Dictionary else c[k]
		d["rng_state"] = c["rng"].state
		cs.append(d)
	return {"cars": cs, "round": round, "rng": rng.state, "legend_deck": legend_deck.duplicate(), "legend_card": legend_card,
		"finished": finished.map(func(c): return c["i"]), "order": order.map(func(c): return c["i"]), "adr_set": adr_set.duplicate()}

func restore(snap: Dictionary) -> void:
	for d in snap["cars"]:
		var c: Dictionary = cars[int(d["i"])]
		for k in d:
			if k == "rng_state":
				continue
			c[k] = d[k].duplicate(true) if d[k] is Array or d[k] is Dictionary else d[k]
		c["rng"].state = d["rng_state"]
	round = snap["round"]
	rng.state = snap["rng"]
	legend_deck = snap["legend_deck"].duplicate()
	legend_card = snap["legend_card"]
	finished = snap["finished"].map(func(i): return cars[i])
	order = snap["order"].map(func(i): return cars[i])
	adr_set = snap["adr_set"].duplicate()
	events.clear()

func state_hash() -> int:
	var parts: Array = [round]
	for c in cars:
		parts.append([c["s"], c["lane"], c["gear"], c["engine"], c["hand"].size(), c["deck"].size(), c["discard"].size(), c["fin"]])
	return hash(str(parts))

func lap_of(car: Dictionary) -> int:
	return clampi(int(floor(float(car["s"]) / track.n)) + 1, 1, track.laps)

func lap_text(car: Dictionary) -> String:
	if car["fin"] or car["s"] >= track.finish_s():
		return "arrivata"
	if car["s"] < 0:
		return "in griglia"
	return "giro %d/%d" % [lap_of(car), track.laps]

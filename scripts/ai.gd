## Pilota automatico: sceglie marcia e carte, spinta, adrenalina, scia e scarti.
## Valuta ogni combinazione di carte con la velocità attesa, il Calore che costano le curve,
## il rischio di testacoda e la situazione in cui si troverà al turno successivo.
class_name AI
extends RefCounted

const SPIN_PEN := 14.0

static func _heat_value(R: Rules, car: Dictionary, level: int) -> float:
	var rem: int = R.track.finish_s() - int(car["s"])
	var w := 1.1
	if car["engine"] <= 1:
		w = 2.0
	elif car["engine"] <= 3:
		w = 1.45
	if rem < 12:
		w *= 0.35
	elif rem < 25:
		w *= 0.7
	if level <= 0:
		w *= 0.8
	return w

## Distribuzione della somma di n carte Stress (ognuna una carta base 1-4 presa dal mazzo).
static func _stress_dist(R: Rules, car: Dictionary, ns: int) -> Dictionary:
	var counts := {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}
	var tot := 0.0
	for pile in [car["deck"], car["discard"]]:
		for c in pile:
			if c["t"] == "s":
				counts[int(c["v"])] += 1.0
				tot += 1.0
	if tot == 0:
		counts = {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0}
		tot = 4.0
	var single := {}
	for v in counts:
		single[v] = counts[v] / tot
	var dist := {0: 1.0}
	for k in ns:
		var nd := {}
		for a in dist:
			for b in single:
				nd[a + b] = nd.get(a + b, 0.0) + dist[a] * single[b]
		dist = nd
	return dist

static func _combos(items: Array, k: int) -> Array:
	var out: Array = []
	if k == 0:
		out.append([])
		return out
	if items.size() < k:
		return out
	for i in range(items.size() - k + 1):
		for rest in _combos(items.slice(i + 1), k - 1):
			var c: Array = [items[i]]
			c.append_array(rest)
			out.append(c)
	return out

## Scelta di marcia e carte: {g, c}.
static func plan(R: Rules, car: Dictionary) -> Dictionary:
	var level: int = car.get("level", 1)
	var hand: Array = car["hand"]
	var play_idx: Array = []
	for i in hand.size():
		if Rules.playable(hand[i]):
			play_idx.append(i)
	var best := {}
	var best_score := -1e9
	var scored: Array = []
	for g in range(1, 5):
		var sc := R.shift_cost(car, g)
		if sc > car["engine"]:
			continue
		if play_idx.size() < g:
			continue
		var seen := {}
		for combo in _combos(play_idx, g):
			var key: Array = []
			for x in combo:
				key.append("%s%d" % [hand[x]["t"], hand[x]["v"]])
			key.sort()
			var ks := str(key)
			if seen.has(ks):
				continue
			seen[ks] = true
			var s := _eval(R, car, g, combo, sc, level)
			scored.append([s, {"g": g, "c": combo}])
			if s > best_score:
				best_score = s
				best = {"g": g, "c": combo}
	if best.is_empty():
		# mano intasata: si gioca quel che si può nella marcia più bassa raggiungibile
		var g := int(car["gear"])
		for gg in range(1, 5):
			if R.shift_cost(car, gg) <= car["engine"]:
				g = gg
				break
		return {"g": g, "c": play_idx.slice(0, mini(g, play_idx.size()))}
	if level <= 0 and scored.size() > 1:
		# livello facile: ogni tanto non sceglie la mossa migliore
		scored.sort_custom(func(a, b): return a[0] > b[0])
		var pick: int = car["rng"].randi_range(0, mini(2, scored.size() - 1)) if car["rng"].randf() < 0.35 else 0
		return scored[pick][1]
	return best

static func _eval(R: Rules, car: Dictionary, g: int, combo: Array, shift: int, level: int) -> float:
	var hand: Array = car["hand"]
	var fixed := 0
	var ns := 0
	for x in combo:
		var c: Dictionary = hand[x]
		if c["t"] == "x":
			ns += 1
		else:
			fixed += Rules.card_value(c)
	var wh := _heat_value(R, car, level)
	var s: int = car["s"]
	var avail: int = car["engine"] - shift
	var dist := _stress_dist(R, car, ns)
	var fin := R.track.finish_s()
	# carte rimaste in mano per il turno dopo
	var rest: Array = []
	for i in hand.size():
		if not combo.has(i) and Rules.playable(hand[i]):
			rest.append(2.5 if hand[i]["t"] == "x" else float(Rules.card_value(hand[i])))
	rest.sort()
	var score := 0.0
	var worst_cost := 0
	for sv in dist:
		var p: float = dist[sv]
		var v: int = fixed + int(sv)
		var pos := s + v
		var cost := R.corner_cost(car, s, pos, v)
		worst_cost = maxi(worst_cost, cost)
		var val := 0.0
		if cost > avail:
			var lines := R.track.crossed(s, pos)
			var back: int = int(lines[0]["b"]) - 1 if not lines.is_empty() else pos
			val = float(back - s) - SPIN_PEN - (4.0 if g >= 3 else 2.0)
		else:
			val = float(mini(pos, fin + 3) - s) - cost * wh
			# situazione al turno dopo: costretti a entrare in curva troppo veloci?
			if pos < fin:
				var nc := R.track.next_corner(pos)
				if int(nc["b"]) <= fin:
					var d: int = int(nc["b"]) - pos
					var lim2 := R.corner_limit(nc["k"])
					var gmin := maxi(1, g - 1)
					var m := 0.0
					for k in gmin:
						m += rest[k] if k < rest.size() else 2.0
					if m >= d and m > lim2:
						var over := m - lim2
						var left := avail - cost
						val -= over * wh * 0.75
						if over > left:
							val -= 6.0
					# troppo lenti davanti a un lungo rettilineo: leggero svantaggio in prima
					if g == 1 and d > 10:
						val -= 0.8
		score += p * val
	score -= shift * wh
	# raffreddamento delle marce basse
	var h := R.heat_in_hand(car)
	var cool := 3 if g == 1 else (1 if g == 2 else 0)
	if h > 0 and cool > 0:
		var wc := 0.9 if car["engine"] <= 2 else 0.55
		score += mini(h, cool) * wc
	# togliersi di mano le carte Stress quando non c'è rischio
	if ns > 0 and worst_cost == 0:
		score += 0.5 * ns
	# tenere carte basse per le curve vicine
	return score

## Reazione dopo aver girato le carte: elenco di azioni ("a" adrenalina, "b" spinta).
static func react(R: Rules, car: Dictionary) -> Array:
	var out: Array = []
	var level: int = car.get("level", 1)
	var wh := _heat_value(R, car, level)
	var v := R.speed(car)
	var s0: int = car["s0"]
	var s: int = car["s"]
	if R.can_adrenaline(car):
		var c0 := R.corner_cost(car, s0, s, v)
		var c1 := R.corner_cost(car, s0, s + 1, v + 1)
		if c1 <= c0 or (c1 - c0 <= 1 and c1 <= car["engine"] and wh < 0.6):
			out.append("a")
			v += 1
			s += 1
	if R.can_boost(car):
		var free := R.sector_fx(car).has("free")
		var pay := 0 if free else 1
		var left: int = car["engine"] - pay
		var risky := false
		var exp_extra := 0.0
		var base := R.corner_cost(car, s0, s, v)
		for b in [1, 2, 3, 4]:
			var cb := R.corner_cost(car, s0, s + b, v + b)
			if cb > left:
				risky = true
			exp_extra += 0.25 * (cb - base)
		var reserve := 1 if R.track.finish_s() - s > 15 else 0
		var gain := 2.5 - wh * (pay + exp_extra)
		if not risky and left >= reserve and gain > 0.4:
			out.append("b")
	return out

static func slip(R: Rules, car: Dictionary) -> bool:
	var amt := R.slip_amount(car)
	if amt <= 0:
		return false
	var v := R.speed(car)
	var c0 := R.corner_cost(car, car["s0"], car["s"], v)
	var c1 := R.corner_cost(car, car["s0"], car["s"] + amt, v)
	if c1 > car["engine"]:
		return false
	return c1 == c0 or (c1 - c0) * _heat_value(R, car, car.get("level", 1)) < amt * 0.6

static func discards(R: Rules, car: Dictionary) -> Array:
	if not R.can_discard(car):
		return []
	var s: int = car["s"]
	var nc := R.track.next_corner(s)
	var d: int = int(nc["b"]) - s
	var lim := R.corner_limit(nc["k"])
	var rem: int = R.track.finish_s() - s
	var out: Array = []
	var hand: Array = car["hand"]
	for i in hand.size():
		var c: Dictionary = hand[i]
		if not Rules.discardable(c):
			continue
		var v := Rules.card_value(c)
		if rem < 14 and v <= 1:
			out.append(i)
		elif d <= 7 and lim <= 4 and v >= 5:
			out.append(i)
		elif d > 12 and v == 0:
			out.append(i)
		elif d > 16 and v == 1 and car["gear"] >= 3:
			out.append(i)
	return out.slice(0, 3)

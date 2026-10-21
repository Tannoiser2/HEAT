## Pilota automatico: sceglie marcia e carte, valori dei freni, spinta, adrenalina, scia, scarti e potenziamenti.
## Valuta ogni combinazione di carte con la velocità attesa, il Calore che costano le curve,
## il rischio di testacoda e la situazione in cui si troverà al turno successivo.
class_name AI
extends RefCounted

const SPIN_PEN := 14.0
## Casualità del pilota automatico: separata da quella della corsa, così online non cambia i mazzi.
static var arng := RandomNumberGenerator.new()

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
	elif level >= 2:
		w *= 1.05
	return w * float(car.get("wmul", 1.0))

## Distribuzione della somma di n carte base pescate dal mazzo (Stress e simboli "+").
static func _stress_dist(car: Dictionary, ns: int) -> Dictionary:
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

static func _key(c: Dictionary) -> String:
	return "%s%d_%d" % [c["t"], int(c["v"]), int(c.get("id", 0))]

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
				key.append(_key(hand[x]))
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
		var pick: int = arng.randi_range(0, mini(2, scored.size() - 1)) if arng.randf() < 0.35 else 0
		return scored[pick][1]
	return best

## Tutte le combinazioni di valori per le carte con scelta (freni).
static func _choice_sets(chs: Array) -> Array:
	var out: Array = [[]]
	for ch in chs:
		var nx: Array = []
		for pre in out:
			for v in ch:
				var p: Array = pre.duplicate()
				p.append(int(v))
				nx.append(p)
		out = nx
	return out

static func _eval(R: Rules, car: Dictionary, g: int, combo: Array, shift: int, level: int) -> float:
	var hand: Array = car["hand"]
	var fixed := 0
	var ns := 0
	var heat_cost := 0
	var lim := 0
	var cool_extra := 0
	var chs: Array = []
	var bonus := 0.0
	for x in combo:
		var c: Dictionary = hand[x]
		if c["t"] == "x":
			ns += 1
			bonus += 0.5
		elif c["t"] == "g":
			var info := Rules.ginfo(c)
			if info.has("ch"):
				chs.append(info["ch"])
			else:
				fixed += int(info.get("v", 0))
			ns += int(info.get("plus", 0))
			heat_cost += int(info.get("heat", 0))
			lim += int(info.get("lim", 0))
			cool_extra += int(info.get("cool", 0))
			bonus += 0.6 * int(info.get("rs", 0)) * mini(1, R.heat_in_hand(car) + 1) + 0.3 * int(info.get("slip", 0)) + 0.4 * int(info.get("salv", 0)) / 2.0 + 0.5 * int(info.get("sc", 0))
			bonus -= 0.08 * int(info.get("scrap", 0))
			if info.get("ref", false):
				bonus += 0.8
		else:
			fixed += Rules.card_value(c)
	var wh := _heat_value(R, car, level)
	var s: int = car["s"]
	var avail: int = car["engine"] - shift - heat_cost
	if avail < 0:
		return -1e6
	var dist := _stress_dist(car, ns)
	var fin := R.track.finish_s()
	var rest: Array = []
	for i in hand.size():
		if not combo.has(i) and Rules.playable(hand[i]):
			rest.append(2.5 if hand[i]["t"] == "x" else float(Rules.card_value(hand[i])))
	rest.sort()
	var sets := _choice_sets(chs)
	var score := 0.0
	var worst_cost := 0
	for sv in dist:
		var p: float = dist[sv]
		var best_val := -1e9
		for cs in sets:
			var v: int = fixed + int(sv)
			for x in cs:
				v += int(x)
			var val := _outcome(R, car, s, v, avail, lim, wh, g, rest, fin)
			if val > best_val:
				best_val = val
				var cost := R.corner_cost(car, s, s + v, v, lim)
				worst_cost = maxi(worst_cost, cost)
		score += p * best_val
	score -= (shift + heat_cost) * wh
	var h := R.heat_in_hand(car)
	var cool := (3 if g == 1 else (1 if g == 2 else 0)) + cool_extra
	if h > 0 and cool > 0:
		var wc := 0.9 if car["engine"] <= 2 else 0.55
		score += mini(h, cool) * wc
	if worst_cost == 0:
		score += bonus
	else:
		score += bonus * 0.5
	return score

static func _outcome(R: Rules, car: Dictionary, s: int, v: int, avail: int, lim: int, wh: float, g: int, rest: Array, fin: int) -> float:
	var pos := s + v
	var cost := R.corner_cost(car, s, pos, v, lim)
	if cost > avail:
		var lines := R.track.crossed(s, pos)
		var back: int = int(lines[0]["b"]) - 1 if not lines.is_empty() else pos
		return float(back - s) - SPIN_PEN - (4.0 if g >= 3 else 2.0)
	var val := float(mini(pos, fin + 3) - s) - cost * wh
	if int(car.get("level", 1)) >= 2 and pos < fin:
		# Esperto: guarda anche il turno dopo, con le carte che restano in mano
		val += 0.85 * _next_turn(R, car, pos, g, avail - cost, wh, rest, fin)
		return val
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
			if g == 1 and d > 10:
				val -= 0.8
	return val

## Miglior turno successivo (approssimato): marcia vicina, carte rimaste in mano più pescate medie.
static func _next_turn(R: Rules, car: Dictionary, pos: int, g: int, avail: int, wh: float, rest: Array, fin: int) -> float:
	var cards: Array = rest.duplicate()
	while cards.size() < 7:
		cards.append(2.3)
	cards.sort()
	var best := -1e9
	for g2 in [g - 1, g, g + 1]:
		if g2 < 1 or g2 > 4:
			continue
		# combinazioni di g2 carte: si provano le più basse, le più alte e quelle intermedie
		var n := cards.size()
		for start in range(0, n - g2 + 1):
			var v := 0.0
			for k in g2:
				v += cards[start + k]
			var vi := int(round(v))
			var p2 := pos + vi
			var c2 := R.corner_cost(car, pos, p2, vi)
			var val := 0.0
			if c2 > avail:
				val = -SPIN_PEN
			else:
				val = float(mini(p2, fin + 3) - pos) - c2 * wh
			if val > best:
				best = val
	return best - 8.0

## Valori dei freni dopo aver girato le carte: quelli che portano più avanti senza testacoda.
static func choices(R: Rules, car: Dictionary) -> Array:
	var pend := R.pending_choices(car)
	if pend.is_empty():
		return []
	var chs: Array = []
	for c in pend:
		chs.append(Rules.ginfo(c)["ch"])
	var wh := _heat_value(R, car, car.get("level", 1))
	var base := R.speed(car)
	var best: Array = []
	var bs := -1e9
	for cs in _choice_sets(chs):
		var v := base
		for x in cs:
			v += int(x)
		var cost := R.corner_cost(car, car["s"], car["s"] + v, v)
		var val := float(v) - cost * wh
		if cost > car["engine"]:
			val -= 30.0
		if val > bs:
			bs = val
			best = cs
	return best

## Reazione dopo aver girato le carte: elenco di azioni ("a" adrenalina, "b" spinta, "c" accelerazione, "f" scatto, "p<k>" gioco diretto).
## Le applica una per una (servono le posizioni aggiornate): chi chiama deve usare una copia o rifarle.
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
	# gioco diretto
	for k in R.direct_cards(car):
		var c: Dictionary = car["hand"][k]
		var info := Rules.ginfo(c)
		var dv := int(info.get("v", 0)) + 2 * int(info.get("plus", 0))
		var need := int(info.get("heat", 0))
		var cost0 := R.corner_cost(car, s0, s, v)
		var cost1 := R.corner_cost(car, s0, s + dv, v + dv)
		if dv > 0 and cost1 + need <= car["engine"] - 1 and (cost1 - cost0 + need) * wh < dv * 0.8:
			out.append("p%d" % k)
			break
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

## Decide l'accelerazione e lo scatto dopo le altre reazioni.
static func react_late(R: Rules, car: Dictionary) -> Array:
	var out: Array = []
	if R.can_accelerate(car):
		var n := int(car["sym"])
		var v := R.speed(car)
		var c0 := R.corner_cost(car, car["s0"], car["s"], v)
		var c1 := R.corner_cost(car, car["s0"], car["s"] + n, v + n)
		if c1 <= car["engine"] and (c1 - c0) * _heat_value(R, car, car.get("level", 1)) < n * 0.8:
			out.append("c")
	if R.draft_amount(car) > 0:
		var m := R.draft_amount(car)
		var v2 := R.speed(car)
		if R.corner_cost(car, car["s0"], car["s"] + m, v2) <= R.corner_cost(car, car["s0"], car["s"], v2) or R.corner_cost(car, car["s0"], car["s"] + m, v2) <= car["engine"] - 1:
			out.append("f")
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
		if c["t"] == "g":
			var info := Rules.ginfo(c)
			if info.get("ref", false) or info.has("ch") or int(info.get("plus", 0)) > 0:
				continue
			if int(info.get("heat", 0)) > car["engine"]:
				out.append(i)
			continue
		if rem < 14 and v <= 1:
			out.append(i)
		elif d <= 7 and lim <= 4 and v >= 5:
			out.append(i)
		elif d > 12 and v == 0:
			out.append(i)
		elif d > 16 and v == 1 and car["gear"] >= 3:
			out.append(i)
	return out.slice(0, 3)

## Valore di una carta potenziamento per il draft.
static func upg_score(id: int) -> float:
	var i: Dictionary = Rules.UPG[id]
	if i.get("hc", false):
		return -1.0
	var v := float(i.get("v", 0))
	if i.has("ch"):
		v = float(i["ch"].max()) * 0.85 + 0.6
	var s := v * 0.9 + 2.4 * int(i.get("plus", 0))
	s += 1.1 * int(i.get("cool", 0)) + 0.6 * int(i.get("slip", 0)) + 0.9 * int(i.get("rs", 0)) + 0.5 * int(i.get("salv", 0))
	s += 1.3 * int(i.get("lim", 0)) - 1.6 * int(i.get("heat", 0)) - 0.25 * int(i.get("scrap", 0))
	s += 1.0 * int(i.get("sc", 0)) + 0.7 * int(i.get("dr", 0)) + 1.0 * int(i.get("xs", 0))
	if i.get("ref", false):
		s += 1.5
	if i.get("dp", false):
		s += 1.0
	if i.get("acc", false):
		s += 1.5
	return s

static func draft_pick(R: Rules, car: Dictionary) -> int:
	var best := -1
	var bs := -1e9
	for id in R.draft_market:
		var sc: float = upg_score(int(id)) + arng.randf() * 0.3
		if sc > bs:
			bs = sc
			best = int(id)
	return best

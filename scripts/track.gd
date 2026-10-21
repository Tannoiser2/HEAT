## Una pista di HEAT: caselle (ognuna con due posti), curve con limite di velocità,
## linee delle Leggende, settori e caratteristiche speciali (allagamenti, gallerie, ghiaia).
## Le posizioni delle auto sono "assolute": s = caselle percorse dal traguardo (negativo sulla griglia),
## la casella sulla pista è posmod(s, n).
class_name Track
extends RefCounted

var key := ""
var name := ""
var image := ""
var aspect := 1.5
var laps := 2
var heat := 6
var stress := 3
var n := 0
var spaces: Array = []      # {spots:[[u,v],[u,v]], ang, corner?, legend?, chev?, flood?, tunnel?, gravel?}
var corners: Array = []     # {c, lim, legend, group}
var groups: Array = []      # gruppi di curve (le chicane contano una volta per meteo e condizioni)
var corner_at := {}         # indice casella -> indice in corners

static var _all: Array = []

static func all() -> Array:
	if _all.is_empty():
		var f := FileAccess.open("res://data/tracks.json", FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		for d in data["tracks"]:
			var t := Track.new()
			t._load(d)
			_all.append(t)
	return _all

static func by_key(k: String) -> Track:
	for t in all():
		if t.key == k:
			return t
	return all()[0]

## Copia indipendente (per cambiare il numero di giri senza toccare l'originale).
func clone() -> Track:
	var t := Track.new()
	t.key = key
	t.name = name
	t.image = image
	t.aspect = aspect
	t.laps = laps
	t.heat = heat
	t.stress = stress
	t.n = n
	t.spaces = spaces
	t.corners = corners
	t.groups = groups
	t.corner_at = corner_at
	return t

func _load(d: Dictionary) -> void:
	key = d["key"]
	name = d["name"]
	image = d["image"]
	aspect = float(d["aspect"])
	laps = int(d["laps"])
	heat = int(d["heat"])
	stress = int(d["stress"])
	spaces = d["spaces"]
	n = spaces.size()
	var legend_lines: Array = []
	for i in n:
		if spaces[i].has("legend"):
			legend_lines.append(i)
		if spaces[i].has("corner"):
			corner_at[i] = corners.size()
			corners.append({"c": i, "lim": int(spaces[i]["corner"])})
	# linea delle Leggende di ogni curva: l'ultima prima della curva (anche se coincide con la curva precedente)
	for k in corners.size():
		var c: int = corners[k]["c"]
		var best := -1
		var bd := 999
		for lb in legend_lines:
			var dd := posmod(c - int(lb), n)
			if dd > 0 and dd < bd:
				bd = dd
				best = int(lb)
		if best < 0 or bd > 24:
			best = posmod(c - 6, n)
		corners[k]["legend"] = best
	# gruppi: curve consecutive con lo stesso limite a poche caselle formano una chicane
	for k in corners.size():
		var c: int = corners[k]["c"]
		if k > 0 and corners[k]["lim"] == corners[k - 1]["lim"] and c - int(corners[k - 1]["c"]) <= 5:
			groups[-1].append(k)
		else:
			groups.append([k])
		corners[k]["group"] = groups.size() - 1

func idx(s: int) -> int:
	return posmod(s, n)

func space(s: int) -> Dictionary:
	return spaces[posmod(s, n)]

func finish_s() -> int:
	return laps * n

## Linee di curva attraversate andando da s0 (esclusa) a s1: elenco di {b, k} con b = prima casella oltre la linea.
func crossed(s0: int, s1: int) -> Array:
	var out: Array = []
	if s1 <= s0:
		return out
	for s in range(s0, s1):
		var i := posmod(s, n)
		if corner_at.has(i):
			out.append({"b": s + 1, "k": corner_at[i]})
	return out

## Prossima linea di curva davanti a s: {b, k}. b = prima casella oltre la linea.
func next_corner(s: int) -> Dictionary:
	for d in range(0, n):
		var i := posmod(s + d, n)
		if corner_at.has(i):
			return {"b": s + d + 1, "k": corner_at[i]}
	return {"b": s + n, "k": 0}

## Settore (gruppo di curve che lo precede) della casella s.
func sector_of(s: int) -> int:
	var i := posmod(s, n)
	# il settore k va dalla casella dopo l'ultima linea del gruppo k fino all'ultima linea del gruppo successivo
	var best := groups.size() - 1
	var bd := 9999
	for g in groups.size():
		var last: int = corners[groups[g][-1]]["c"]
		var dd := posmod(i - (last + 1), n)
		if dd < bd:
			bd = dd
			best = g
	return best

func spot_uv(s: int, lane: int) -> Vector2:
	if lane >= 2:
		# a bordo pista, fuori dalla linea ideale (Leggenda agile in una casella piena)
		var a := spot_uv(s, 0)
		return a + (a - spot_uv(s, 1)) * 0.85
	var sp: Array = space(s)["spots"][lane]
	return Vector2(float(sp[0]), float(sp[1]))

func center_uv(s: int) -> Vector2:
	return (spot_uv(s, 0) + spot_uv(s, 1)) * 0.5

func angle(s: int) -> float:
	return float(space(s)["ang"])

## Testo breve per la cronaca: "curva 3 (limite 4)".
func corner_name(k: int) -> String:
	return "curva %d (limite %d)" % [k + 1, corners[k]["lim"]]

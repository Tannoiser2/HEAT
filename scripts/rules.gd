## Regole di HEAT: Pedal to the Metal (gioco base, Leggende, meteo e condizioni della strada,
## caratteristiche delle piste delle espansioni). Nessuna interfaccia: solo stato e passi del turno.
## Tutto è deterministico a partire dal seme: ogni auto mescola il suo mazzo con un suo generatore,
## così online basta scambiarsi le scelte dei giocatori.
class_name Rules
extends RefCounted

## I primi 8 colori hanno un mazzo da pilota; gli ultimi 4 (espansione Legends) corrono solo come Leggende.
const COLOR_KEYS := ["rosso", "blu", "giallo", "grigio", "verde", "nero", "viola", "arancio", "bianco", "rosa", "turchese", "sabbia"]
const COLOR_NAMES := ["Rossa", "Blu", "Gialla", "Argento", "Verde", "Nera", "Viola", "Arancione", "Bianca", "Rosa", "Turchese", "Sabbia"]
const COLORS := [Color("#D8312B"), Color("#2C64C8"), Color("#F2C42C"), Color("#B9BEC4"), Color("#2E9C4E"), Color("#2A2A2E"), Color("#9B3FC4"), Color("#EE7A22"),
	Color("#F1EFE6"), Color("#E87DB5"), Color("#2FB3A6"), Color("#CDB68A")]
const NUMBERS := [7, 2, 5, 11, 3, 9, 8, 4, 1, 17, 21, 6]
const PLAYER_COLORS := 8
const MAX_CARS := 12
const LEGEND_COLORS := [0, 1, 2, 3, 4, 5]      # le carte Leggenda del gioco base hanno questi sei colori

## Espansione Legends (2026): 36 carte Leggenda (mazzi verde, giallo, rosso) con la velocità di tutti
## i 12 colori (indici come COLOR_KEYS) e i colori con la stella. Immagini: assets/carte/lx_<indice>.webp
const LX_CARDS := [
	{"d": "verde", "v": [9, 11, 12, 13, 10, 14, 17, 15, 20, 16, 19, 18], "st": [1, 6]},
	{"d": "verde", "v": [10, 14, 16, 18, 12, 20, 13, 9, 19, 11, 17, 15], "st": [9, 10]},
	{"d": "verde", "v": [11, 17, 20, 12, 14, 15, 19, 18, 16, 9, 13, 10], "st": [0, 1]},
	{"d": "verde", "v": [12, 19, 10, 9, 16, 13, 11, 17, 15, 18, 20, 14], "st": [6, 7]},
	{"d": "verde", "v": [13, 9, 14, 20, 18, 19, 10, 11, 17, 15, 12, 16], "st": [7, 8]},
	{"d": "verde", "v": [14, 12, 18, 11, 20, 17, 16, 19, 10, 13, 15, 9], "st": [5, 9]},
	{"d": "verde", "v": [15, 20, 11, 17, 9, 10, 12, 14, 18, 19, 16, 13], "st": [2, 3]},
	{"d": "verde", "v": [16, 13, 19, 15, 11, 12, 18, 20, 14, 10, 9, 17], "st": [4, 11]},
	{"d": "verde", "v": [17, 10, 15, 19, 13, 11, 14, 16, 9, 20, 18, 12], "st": [0, 5]},
	{"d": "verde", "v": [19, 16, 9, 14, 17, 18, 15, 13, 11, 12, 10, 20], "st": [4, 8]},
	{"d": "verde", "v": [20, 18, 17, 10, 15, 16, 9, 12, 13, 14, 11, 19], "st": [2, 10]},
	{"d": "verde", "v": [18, 15, 13, 16, 19, 9, 20, 10, 12, 17, 14, 11], "st": [9, 11]},
	{"d": "rosso", "v": [9, 11, 12, 13, 10, 14, 17, 15, 20, 16, 19, 18], "st": [0, 1, 3, 6, 7, 10]},
	{"d": "rosso", "v": [10, 14, 16, 18, 12, 20, 13, 9, 19, 11, 17, 15], "st": [6, 7, 8, 9, 10, 11]},
	{"d": "rosso", "v": [11, 17, 20, 12, 14, 15, 19, 18, 16, 9, 13, 10], "st": [0, 1, 5, 6, 9, 10]},
	{"d": "rosso", "v": [20, 18, 17, 10, 15, 16, 9, 12, 13, 14, 11, 19], "st": [2, 4, 6, 8, 10, 11]},
	{"d": "rosso", "v": [19, 16, 9, 14, 17, 18, 15, 13, 11, 12, 10, 20], "st": [0, 2, 4, 6, 7, 8]},
	{"d": "rosso", "v": [18, 15, 13, 16, 19, 9, 20, 10, 12, 17, 14, 11], "st": [1, 2, 4, 5, 9, 11]},
	{"d": "rosso", "v": [17, 10, 15, 19, 13, 11, 14, 16, 9, 20, 18, 12], "st": [0, 2, 3, 4, 5, 8]},
	{"d": "rosso", "v": [16, 13, 19, 15, 11, 12, 18, 20, 14, 10, 9, 17], "st": [1, 2, 3, 4, 10, 11]},
	{"d": "rosso", "v": [15, 20, 11, 17, 9, 10, 12, 14, 18, 19, 16, 13], "st": [0, 2, 3, 4, 9, 11]},
	{"d": "rosso", "v": [14, 12, 18, 11, 20, 17, 16, 19, 10, 13, 15, 9], "st": [3, 5, 7, 9, 10, 11]},
	{"d": "rosso", "v": [13, 9, 14, 20, 18, 19, 10, 11, 17, 15, 12, 16], "st": [0, 1, 5, 7, 8, 9]},
	{"d": "rosso", "v": [12, 19, 10, 9, 16, 13, 11, 17, 15, 18, 20, 14], "st": [1, 3, 5, 6, 7, 8]},
	{"d": "giallo", "v": [9, 11, 12, 13, 10, 14, 17, 15, 20, 16, 19, 18], "st": [0, 3, 7, 10]},
	{"d": "giallo", "v": [10, 14, 16, 18, 12, 20, 13, 9, 19, 11, 17, 15], "st": [6, 7, 8, 11]},
	{"d": "giallo", "v": [11, 17, 20, 12, 14, 15, 19, 18, 16, 9, 13, 10], "st": [5, 6, 9, 10]},
	{"d": "giallo", "v": [12, 19, 10, 9, 16, 13, 11, 17, 15, 18, 20, 14], "st": [1, 3, 5, 8]},
	{"d": "giallo", "v": [13, 9, 14, 20, 18, 19, 10, 11, 17, 15, 12, 16], "st": [0, 1, 5, 9]},
	{"d": "giallo", "v": [14, 12, 18, 11, 20, 17, 16, 19, 10, 13, 15, 9], "st": [3, 7, 10, 11]},
	{"d": "giallo", "v": [16, 13, 19, 15, 11, 12, 18, 20, 14, 10, 9, 17], "st": [1, 2, 3, 10]},
	{"d": "giallo", "v": [15, 20, 11, 17, 9, 10, 12, 14, 18, 19, 16, 13], "st": [0, 4, 9, 11]},
	{"d": "giallo", "v": [17, 10, 15, 19, 13, 11, 14, 16, 9, 20, 18, 12], "st": [2, 3, 4, 8]},
	{"d": "giallo", "v": [19, 16, 9, 14, 17, 18, 15, 13, 11, 12, 10, 20], "st": [0, 2, 6, 7]},
	{"d": "giallo", "v": [18, 15, 13, 16, 19, 9, 20, 10, 12, 17, 14, 11], "st": [1, 2, 4, 5]},
	{"d": "giallo", "v": [20, 18, 17, 10, 15, 16, 9, 12, 13, 14, 11, 19], "st": [4, 6, 8, 11]},
]
## Livelli di difficoltà dell'espansione: mazzi usati (1 = qualunque mazzo, senza stelle).
const LX_LEVEL_DECKS := [[], ["verde"], ["verde"], ["verde", "giallo"], ["giallo"], ["giallo", "rosso"], ["rosso"]]
## Carte Power Up (due copie ciascuna): abilità della stella (s) e dei Rivali (r).
## slip scia di 2, full a tutto gas, draft scatto, adj limite +2, reck temerario, imp ostruzione, nimble agile.
const POWER_UPS := [
	{"s": "slip", "r": "imp"}, {"s": "slip", "r": "full"}, {"s": "slip", "r": "adj"}, {"s": "slip", "r": "nimble"},
	{"s": "slip", "r": "reck"}, {"s": "slip", "r": "slip"}, {"s": "full", "r": "imp"}, {"s": "full", "r": "adj"},
	{"s": "full", "r": "reck"}, {"s": "full", "r": "slip"}, {"s": "full", "r": "full"}, {"s": "full", "r": "nimble"},
	{"s": "draft", "r": "adj"}, {"s": "draft", "r": "nimble"}, {"s": "draft", "r": "slip"}, {"s": "draft", "r": "imp"},
	{"s": "draft", "r": "reck"}, {"s": "draft", "r": "full"},
]
const ABILITY_NAMES := {"slip": "Scia", "full": "A tutto gas", "draft": "Scatto", "adj": "Limite +2", "reck": "Temerario",
	"imp": "Ostruzione", "nimble": "Agile", "plus": "+1 casella"}
const ABILITY_TXT := {"slip": "scia di 2 caselle (con le regole normali della scia)",
	"full": "avvicinandosi a una curva corre 20 caselle; se così passerebbe la linea della curva, si ferma subito prima",
	"draft": "fino a 3 caselle in più, tutte libere, se finisce subito dietro un'auto",
	"adj": "uscendo da una curva aggiunge 2 alla velocità",
	"reck": "uscendo da una curva può passare una linea di curva in più",
	"imp": "occupa tutta la sua casella: chi arriva subito dietro non può prendere la scia",
	"nimble": "non viene mai bloccata (se la casella è piena si mette a bordo pista)",
	"plus": "1 casella in più"}
## Carte Rivale: per ogni colore, l'immagine assets/carte/rivale_<indice>.webp con quell'auto.
const RIVAL_ART := [4, 9, 0, 3, 8, 10, 5, 7, 1, 6, 2, 11]
const HAND := 7
var hand_n := 7

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

## Carte potenziamento (modulo Garage) per numero stampato sulla carta.
## v valore, ch valori a scelta, plus simboli "+" (carta base dal mazzo), heat/scrap/lim obbligatori,
## cool raffreddamento, slip scia in più, rs riduci Stress, ref rimetti in cima al mazzo, salv recupera dagli scarti,
## dp gioco diretto, acc accelerazione, sc super raffreddamento, dr scatto (draft), xs scia extra, hc carta Calore.
const UPG := {
	1: {"n": "Trazione integrale", "v": 4, "plus": 1}, 2: {"n": "Trazione integrale", "plus": 3}, 3: {"n": "Trazione integrale", "plus": 1, "cool": 3},
	4: {"n": "Carrozzeria", "v": 3, "rs": 2}, 5: {"n": "Carrozzeria", "v": 5, "rs": 1}, 6: {"n": "Carrozzeria", "v": 1, "rs": 3},
	7: {"n": "Freni", "ch": [1, 2, 3, 4], "heat": 1}, 8: {"n": "Freni", "ch": [1, 3]}, 9: {"n": "Freni", "ch": [2, 4]}, 10: {"n": "Freni", "ch": [1, 5]},
	11: {"n": "Raffreddamento", "v": 6, "heat": 1, "cool": 1}, 12: {"n": "Raffreddamento", "v": 1, "cool": 2}, 13: {"n": "Raffreddamento", "v": 3, "cool": 1},
	14: {"n": "Giri motore", "v": 1, "slip": 2}, 15: {"n": "Giri motore", "v": 2, "slip": 2}, 16: {"n": "Giri motore", "v": 3, "slip": 2},
	17: {"n": "Calore in più", "hc": true},
	18: {"n": "Carrozzeria", "v": 6, "rs": 3, "heat": 1}, 19: {"n": "Carrozzeria", "v": 2, "rs": 1, "cool": 1, "scrap": 2},
	20: {"n": "Carrozzeria", "v": 2, "rs": 1, "slip": 1}, 21: {"n": "Raffreddamento", "v": 4, "scrap": 2, "cool": 1},
	22: {"n": "Carburante", "v": 2, "salv": 2}, 23: {"n": "Carburante", "plus": 1, "salv": 2, "cool": 1},
	24: {"n": "Acceleratore", "v": 1, "dp": true, "scrap": 1}, 25: {"n": "Acceleratore", "v": 2, "dp": true, "scrap": 2},
	26: {"n": "Acceleratore", "v": 3, "dp": true, "scrap": 3}, 27: {"n": "Acceleratore", "v": 4, "dp": true, "heat": 1, "cool": 1},
	28: {"n": "Acceleratore", "plus": 1, "dp": true, "acc": true, "scrap": 5},
	29: {"n": "Giri motore", "plus": 1, "slip": 3}, 30: {"n": "Giri motore", "v": 1, "heat": 1, "slip": 3}, 31: {"n": "Giri motore", "ch": [1, 2], "slip": 1},
	32: {"n": "Sospensioni", "v": 2, "ref": true, "rs": 1}, 33: {"n": "Sospensioni", "v": 2, "ref": true, "cool": 1},
	34: {"n": "Sospensioni", "v": 4, "ref": true}, 35: {"n": "Sospensioni", "v": 1, "ref": true, "slip": 1},
	36: {"n": "Gomme", "v": 2, "lim": -1, "cool": 3}, 37: {"n": "Gomme", "v": 1, "scrap": 2, "lim": 1}, 38: {"n": "Gomme", "v": 2, "scrap": 2, "lim": 1},
	39: {"n": "Gomme", "v": 3, "lim": -1, "cool": 2}, 40: {"n": "Gomme", "plus": 1, "lim": 1, "slip": 1, "cool": 1}, 41: {"n": "Gomme", "plus": 2, "lim": 2},
	42: {"n": "Turbocompressore", "v": 7, "heat": 2, "cool": 3}, 43: {"n": "Turbocompressore", "v": 8, "heat": 1, "scrap": 6},
	44: {"n": "Alettoni", "v": 4, "heat": 1, "scrap": 2, "lim": 2}, 45: {"n": "Alettoni", "v": 3, "heat": 1, "scrap": 2, "lim": 2},
	46: {"n": "Alettoni", "v": 6, "heat": 2, "lim": 3}, 47: {"n": "Trazione integrale", "plus": 1, "acc": true},
	49: {"n": "Presa d'aria", "v": 1, "sc": 1, "salv": 4, "lim": -1}, 50: {"n": "Presa d'aria", "v": 0, "sc": 1, "slip": 1, "rs": 1},
	51: {"n": "Presa d'aria", "v": 1, "sc": 1, "cool": 1, "scrap": 1}, 52: {"n": "Presa d'aria", "v": 3, "sc": 1, "scrap": 3},
	53: {"n": "Presa d'aria", "v": 4, "sc": 1, "scrap": 4}, 54: {"n": "Presa d'aria", "plus": 1, "sc": 1, "ref": true, "lim": -1},
	55: {"n": "Alettone anteriore", "plus": 1, "dr": 3}, 56: {"n": "Alettone anteriore", "v": 0, "dr": 1, "dp": true, "ref": true},
	57: {"n": "Alettone anteriore", "v": 2, "dr": 2, "salv": 2, "scrap": 5}, 58: {"n": "Alettone anteriore", "v": 3, "dr": 1, "lim": -1, "scrap": 3},
	59: {"n": "Alettone anteriore", "v": 4, "dr": 1, "ref": true, "scrap": 4}, 60: {"n": "Alettone anteriore", "v": 6, "dr": 2, "heat": 1},
	61: {"n": "Minigonne", "plus": 1, "xs": 1, "lim": 1, "rs": 1}, 62: {"n": "Minigonne", "v": 1, "xs": 1, "slip": 1},
	63: {"n": "Minigonne", "v": 1, "xs": 1, "ref": true}, 64: {"n": "Minigonne", "v": 2, "xs": 1, "dp": true},
	65: {"n": "Minigonne", "ch": [2, 3], "xs": 1}, 66: {"n": "Minigonne", "ch": [4, 6], "xs": 1, "heat": 1},
	# Sponsor (campionato): si usano una volta sola
	101: {"n": "Lord & Co. T.B.", "v": 6, "sp": true}, 102: {"n": "Aperault RPM", "v": 1, "slip": 2, "sp": true},
	103: {"n": "Dramdo Brakes", "ch": [1, 2, 3, 4], "sp": true}, 104: {"n": "Fredo & F.lli C.S.", "v": 4, "cool": 2, "sp": true},
	105: {"n": "De Angeli Wings", "v": 3, "lim": 1, "sp": true}, 106: {"n": "E. Mercury Air System", "v": 0, "sc": 2, "sp": true},
	107: {"n": "Eole Wings Industries", "v": 5, "dr": 2, "sp": true}, 108: {"n": "Thunder Valley Aero", "ch": [0, 4], "xs": 1, "sp": true},
}
const SPONSORS := [101, 102, 103, 104, 105, 106, 107, 108]

## Carte Evento del campionato: stagione, gara, pista, sponsor iniziali, curve della stampa (lettere), effetto.
const EVENTS := [
	{"id": "61-1", "y": 1961, "r": 1, "t": "gb", "sp": 2, "press": "A", "name": "Inaugurazione della nuova tribuna", "txt": "I primi tre a tagliare il traguardo alla fine del primo giro ricevono subito uno sponsor."},
	{"id": "61-2", "y": 1961, "r": 2, "t": "usa", "sp": 1, "press": "B", "name": "Nuovo record di velocità", "txt": "Ogni volta che raggiungi velocità 15 o più ricevi subito uno sponsor."},
	{"id": "61-3", "y": 1961, "r": 3, "t": "italia", "sp": 1, "press": "C", "name": "Sciopero dei piloti", "txt": "Questa corsa ha un giro in meno. Il vincitore riceve 2 punti in più."},
	{"id": "62-1", "y": 1962, "r": 1, "t": "italia", "sp": 2, "press": "E", "name": "Via le restrizioni meccaniche", "txt": "Tutti partono con un Calore in più nel motore."},
	{"id": "62-2", "y": 1962, "r": 2, "t": "gb", "sp": 1, "press": "CE", "name": "Pubblico da record", "txt": "Un giro in più del solito e la mano sale a 8 carte."},
	{"id": "62-3", "y": 1962, "r": 3, "t": "france", "sp": 1, "press": "C", "name": "Corruzione nel comitato", "txt": "I primi tre classificati ricevono un punto in più."},
	{"id": "63-1", "y": 1963, "r": 1, "t": "usa", "sp": 3, "press": "A", "name": "Cambio di sponsor", "txt": "Nessuna regola speciale."},
	{"id": "63-2", "y": 1963, "r": 2, "t": "gb", "sp": 1, "press": "BD", "name": "Prima corsa in diretta TV", "txt": "Se superi 3 auto nello stesso turno ricevi subito uno sponsor."},
	{"id": "63-3", "y": 1963, "r": 3, "t": "france", "sp": 1, "press": "D", "name": "Nuove norme di sicurezza", "txt": "Si parte con 2 Calore e 1 Stress in meno; la mano scende a 6 carte."},
	{"id": "63-4", "y": 1963, "r": 4, "t": "italia", "sp": 0, "press": "D", "name": "Gli sponsor si ritirano", "txt": "Uno Stress in più nel mazzo. Chi fa testacoda è eliminato e prende 0 punti."},
	{"id": "64-1", "y": 1964, "r": 1, "t": "japan", "sp": 0, "press": "BC", "name": "Si va nel mondo", "txt": "Nelle curve della stampa si ricevono 2 sponsor invece di uno."},
	{"id": "64-2", "y": 1964, "r": 2, "t": "france", "sp": 1, "press": "B", "name": "Vento turbolento", "txt": "La scia si può prendere solo in 3ª o 4ª marcia."},
	{"id": "64-3", "y": 1964, "r": 3, "t": "mexico", "sp": 1, "press": "C", "name": "Chicane per la sicurezza", "txt": "Nella fase degli scarti si possono scartare anche le carte Calore."},
	{"id": "64-4", "y": 1964, "r": 4, "t": "japan", "sp": 1, "press": "", "name": "Acquazzone improvviso", "txt": "Nessuno riceve l'adrenalina in questa corsa."},
	{"id": "65-1", "y": 1965, "r": 1, "t": "gb", "sp": 2, "press": "D", "name": "Tieni duro", "txt": "A ogni turno si può scartare al massimo una carta."},
	{"id": "65-2", "y": 1965, "r": 2, "t": "usa", "sp": 0, "press": "C", "name": "Sorridi alla telecamera", "txt": "Nelle curve della stampa lo sponsor arriva solo andando più piano del limite."},
	{"id": "65-3", "y": 1965, "r": 3, "t": "spagna", "sp": 0, "press": "AC", "name": "Visione da galleria", "txt": "Nella fase degli scarti si possono scartare anche le carte Stress."},
	{"id": "65-4", "y": 1965, "r": 4, "t": "nederland", "sp": 1, "press": "B", "name": "Sotto pressione", "txt": "Un giro in più del solito. A ogni giro completato si toglie dal gioco una carta Calore."},
	{"id": "66-1", "y": 1966, "r": 1, "t": "france", "sp": 1, "press": "E", "name": "Manovre difficili", "txt": "La scia vale una casella in meno."},
	{"id": "66-2", "y": 1966, "r": 2, "t": "germania", "sp": 1, "press": "C", "name": "Partenza tranquilla", "txt": "Prima della corsa tutte le carte Stress vanno negli scarti."},
	{"id": "66-3", "y": 1966, "r": 3, "t": "italia", "sp": 0, "press": "", "name": "La folla impazzisce", "txt": "A ogni giro le prime due auto che passano la curva B ricevono uno sponsor (le Leggende contano ma non ricevono carte)."},
	{"id": "66-4", "y": 1966, "r": 4, "t": "sudafrica", "sp": 1, "press": "B", "name": "Controllo tecnico", "txt": "Prima della corsa ogni pilota toglie una carta Calore dal motore e una Stress dal mazzo."},
]
const POINTS := [9, 6, 4, 3, 2, 1]

static func event_by_id(id: String) -> Dictionary:
	for e in EVENTS:
		if e["id"] == id:
			return e
	return {}
const UPG_REGULAR := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
const UPG_ADVANCED := [18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47]
const UPG_EXP := [49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66]

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
var lx_level := 0          # 0 Leggende del gioco base, 1-6 livelli dell'espansione Legends
var lx_deck: Array = []
var pu_deck: Array = []
var pu_card := -1          # carta Power Up del turno
var rivals: Array = []     # indici delle due auto Rivali
var chevrons := true
var adr_n := 1
var order: Array = []      # ordine di movimento del turno in corso
var adr_set: Array = []
var finished: Array = []   # auto arrivate, in ordine
var events: Array = []     # eventi per animazioni e cronaca, svuotati da chi li legge
var started := 0
var garage := 0            # 0 carte iniziali, 1 tre potenziamenti a caso, 2 draft normali, 3 draft con avanzati ed espansioni
var upg_deck: Array = []
var upgrades := {}         # indice auto -> [numeri delle carte potenziamento]
var draft_round := 0
var draft_market: Array = []
var decks_ready := false
var event := {}            # carta Evento della corsa (campionato)
var press: Array = []      # indici delle curve della stampa
var sponsor_deck: Array = []
var sponsor_used: Array = []
var carry := {}            # campionato: indice auto -> {"upg": [...], "spons": [...]}
var out: Array = []        # auto eliminate (evento "gli sponsor si ritirano")
var crowd := {}            # evento "la folla impazzisce": giro -> auto già premiate

# ---------- preparazione ----------

## cfg: [{kind: "human"/"cpu"/"legend", col, name}]; opts: {seed, weather(bool), legend_pro, chevrons, grid: Array opzionale}
func setup(t: Track, cfg: Array, opts: Dictionary) -> void:
	track = t
	seed = int(opts.get("seed", 1))
	rng.seed = seed
	legend_pro = int(opts.get("legend_pro", 0))
	lx_level = int(opts.get("lx", 0))
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
	# Leggende
	legend_deck = range(LEGEND_CARDS.size())
	_shuffle(legend_deck, rng)
	lx_deck = []
	pu_deck = []
	pu_card = -1
	rivals = []
	if lx_level > 0:
		_lx_refill()
		_pu_refill()
		if opts.get("rivals", false) and lx_level >= 2:
			var want: Array = opts.get("rival_cars", [])
			if want.is_empty():
				# corsa singola: le due Leggende più avanti in griglia
				var ls := cars.filter(func(c): return c["kind"] == "legend")
				ls.sort_custom(func(a, b): return a["grid"] < b["grid"])
				for c in ls.slice(0, 2):
					rivals.append(c["i"])
			else:
				for i in want:
					if int(i) < cars.size() and cars[int(i)]["kind"] == "legend":
						rivals.append(int(i))
	# campionato: evento, curve della stampa, sponsor
	event = opts.get("event", {})
	carry = opts.get("carry", {})
	out = []
	crowd = {}
	hand_n = HAND
	if ev("62-2"):
		hand_n = 8
	elif ev("63-3"):
		hand_n = 6
	press = []
	for ch in str(event.get("press", "")):
		var k := "ABCDE".find(ch)
		if k >= 0 and k < track.corners.size():
			press.append(k)
	sponsor_deck = []
	sponsor_used = []
	if not event.is_empty():
		for id in SPONSORS:
			for k in 7:
				sponsor_deck.append(id)
		# gli sponsor già in mano ai piloti non sono nel mazzo
		for i in carry:
			for id in carry[i].get("spons", []):
				var x := sponsor_deck.find(int(id))
				if x >= 0:
					sponsor_deck.remove_at(x)
		_shuffle(sponsor_deck, rng)
	# garage
	garage = int(opts.get("garage", 0))
	upgrades = {}
	decks_ready = false
	if garage == 0:
		build_decks()
	else:
		upg_deck = []
		var pool_lvl := int(opts.get("pool", 2 if garage == 3 else 0))
		var pool: Array = UPG_REGULAR.duplicate() if pool_lvl != 1 else []
		if pool_lvl >= 1:
			pool.append_array(UPG_ADVANCED)
			pool.append_array(UPG_EXP)
		for id in pool:
			upg_deck.append(id)
			upg_deck.append(id)
		_shuffle(upg_deck, rng)
		for car in cars:
			if car["kind"] != "legend":
				upgrades[car["i"]] = []
		if garage == 4:
			# campionato: si tengono i potenziamenti delle corse precedenti e se ne sceglie uno nuovo
			for car in cars:
				if car["kind"] != "legend":
					var have: Array = []
					for id in carry.get(car["i"], {}).get("upg", []):
						have.append(int(id))
						var x := upg_deck.find(int(id))
						if x >= 0:
							upg_deck.remove_at(x)
					upgrades[car["i"]] = have
			draft_round = 0
			next_draft_round()
		elif garage == 1:
			for car in cars:
				if car["kind"] != "legend":
					for k in 3:
						upgrades[car["i"]].append(upg_deck.pop_back())
			build_decks()
		else:
			draft_round = 0
			next_draft_round()

# ---------- garage: draft dei potenziamenti ----------

func drafting() -> bool:
	return not decks_ready

## Nuovo mercato: una carta per auto più tre.
func next_draft_round() -> void:
	draft_round += 1
	for c in draft_market:
		upg_deck.push_front(c)
	draft_market = []
	var n := upgrades.size() + 3
	for k in n:
		if upg_deck.is_empty():
			break
		draft_market.append(upg_deck.pop_back())

## Ordine di scelta del giro: 1° e 3° dal fondo della griglia, 2° dalla pole (campionato: sempre dal fondo).
func draft_order() -> Array:
	var a := cars.filter(func(c): return c["kind"] != "legend")
	a.sort_custom(func(x, y): return x["grid"] < y["grid"])
	if draft_round != 2 or garage == 4:
		a.reverse()
	return a

## Quante carte deve avere ogni auto alla fine del giro di draft in corso.
func draft_target(car: Dictionary) -> int:
	if garage == 4:
		return carry.get(car["i"], {}).get("upg", []).size() + draft_round
	return draft_round

func needs_pick(car: Dictionary) -> bool:
	return upgrades[car["i"]].size() < draft_target(car)

func draft_pick(car: Dictionary, id: int) -> bool:
	var k := draft_market.find(id)
	if k < 0:
		return false
	draft_market.remove_at(k)
	upgrades[car["i"]].append(id)
	events.append({"e": "draft", "car": car["i"], "id": id})
	return true

## Dopo ogni scelta: si passa al giro successivo o, dopo il terzo, si preparano i mazzi.
func draft_advance() -> void:
	var done := true
	for car in cars:
		if car["kind"] != "legend" and needs_pick(car):
			done = false
	if not done:
		return
	if draft_round < (1 if garage == 4 else 3):
		next_draft_round()
	else:
		draft_market = []
		build_decks()

static func make_upg(id: int) -> Dictionary:
	if UPG[id].get("sp", false):
		return {"t": "g", "v": int(UPG[id].get("v", 0)), "id": id, "sp": true}
	if UPG[id].get("hc", false):
		return {"t": "h", "v": 0, "u": true, "id": id}
	return {"t": "g", "v": int(UPG[id].get("v", 0)), "id": id}

## Mazzo di ogni auto: 12 carte base, potenziamenti (o le 3 carte iniziali), Stress; Calore nel motore.
func build_decks() -> void:
	decks_ready = true
	for car in cars:
		if car["kind"] == "legend":
			continue
		var heat := track.heat
		var stress := track.stress
		var deck: Array = []
		for v in [1, 2, 3, 4]:
			for k in 3:
				deck.append({"t": "s", "v": v})
		if garage == 0:
			deck.append({"t": "u", "v": 0})
			deck.append({"t": "u", "v": 5})
			deck.append({"t": "h", "v": 0, "u": true})
		else:
			for id in upgrades.get(car["i"], []):
				deck.append(make_upg(int(id)))
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
		if ev("62-1"):
			heat += 1
		if ev("63-3"):
			heat -= 2
			stress -= 1
		if ev("63-4"):
			stress += 1
		if ev("66-4"):
			heat -= 1
			stress -= 1
		for id in carry.get(car["i"], {}).get("spons", []):
			deck.append(make_upg(int(id)))
		var stress_cards: Array = []
		for k in maxi(stress, 0):
			stress_cards.append({"t": "x", "v": 0})
		if ev("66-2"):
			car["discard"].append_array(stress_cards)
		else:
			deck.append_array(stress_cards)
		_shuffle(deck, car["rng"])
		car["deck"] = deck
		car["engine"] = maxi(heat, 0)
		for k in to_discard:
			car["discard"].append({"t": "h", "v": 0})
		# sponsor della carta Evento direttamente in mano
		for k in int(event.get("sp", 0)):
			_gain_sponsor(car, false)
		_draw(car)

static func _shuffle(a: Array, g: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := g.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp

# ---------- utilità ----------

func ev(id: String) -> bool:
	return event.get("id", "") == id

## Uno sponsor dal mazzo direttamente in mano (se il mazzo è vuoto si rimescolano quelli già usati).
func _gain_sponsor(car: Dictionary, announce := true) -> void:
	if car["kind"] == "legend":
		return
	if sponsor_deck.is_empty():
		sponsor_deck = sponsor_used
		sponsor_used = []
		_shuffle(sponsor_deck, rng)
	if sponsor_deck.is_empty():
		return
	var id: int = sponsor_deck.pop_back()
	car["hand"].append(make_upg(id))
	car["stats"]["sponsor"] = int(car["stats"].get("sponsor", 0)) + 1
	if announce:
		events.append({"e": "sponsor", "car": car["i"], "id": id})

func racing() -> Array:
	return cars.filter(func(c): return not c["fin"])

func humans() -> Array:
	return cars.filter(func(c): return c["kind"] == "human")

func is_legend(car: Dictionary) -> bool:
	return car["kind"] == "legend"

func all_finished() -> bool:
	return racing().is_empty()

func is_out(car: Dictionary) -> bool:
	return out.has(car)

## Ordine di gara: dalla più avanti; a parità di casella prima quella sulla linea ideale.
func race_order() -> Array:
	var a := racing()
	# a bordo pista (Leggenda agile) si riparte per primi nella casella
	a.sort_custom(func(x, y): return x["s"] > y["s"] or (x["s"] == y["s"] and posmod(x["lane"] + 1, 3) < posmod(y["lane"] + 1, 3)))
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
			if c.get("impede", false):
				out.append_array([0, 1])
			elif c["lane"] < 2:
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
	while car["hand"].size() < hand_n:
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
	if c["t"] == "g":
		return int(c.get("cv", c["v"]))
	return int(c["v"]) if c["t"] == "s" or c["t"] == "u" else 0

static func ginfo(c: Dictionary) -> Dictionary:
	return UPG.get(int(c.get("id", 0)), {}) if c.has("id") else {}

## Somma di un effetto sulle carte potenziamento giocate.
func play_sum(car: Dictionary, key: String) -> int:
	var t := 0
	for c in car["play"]:
		if c["t"] == "g" and not c.get("void", false):
			var v = ginfo(c).get(key, 0)
			t += int(v) if not (v is bool) else (1 if v else 0)
	return t

func playable_count(car: Dictionary) -> int:
	return car["hand"].filter(func(c): return playable(c)).size()

func heat_in_hand(car: Dictionary) -> int:
	return car["hand"].filter(func(c): return c["t"] == "h").size()

## Velocità del turno (carte giocate + adrenalina), quella che conta per le curve.
func speed(car: Dictionary) -> int:
	var v := 0
	for c in car["play"]:
		v += card_value(c)
	return v + (1 if car.get("adr_used", false) else 0) + int(car.get("acc_bonus", 0))

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

## Limite della curva per questa auto (gomme e alettoni lo cambiano).
func car_limit(car: Dictionary, k: int) -> int:
	return corner_limit(k) + play_sum(car, "lim")

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
	pu_card = -1
	for c in racing():
		c["play"] = []
		c["adr_used"] = false
		c["boosted"] = false
		c["slipped"] = false
		c["spun"] = false
		c["clutter"] = false
		c["turn_done"] = false
		c["acc_bonus"] = 0
		c["acc_used"] = false
		c["draft_used"] = false
		c["sym"] = 0
		c["slips"] = 0
		c["moved"] = false
		c["press_got"] = 0
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
	return adr_set.has(car["i"]) and not is_legend(car) and not ev("64-4")

## Fase 3a: si girano le carte. Stress e simboli "+" pescano carte base, i potenziamenti pagano
## Calore e scartano dal mazzo. Restituisce quante carte chiedono di scegliere un valore (freni).
func reveal_flip(car: Dictionary) -> int:
	car["s0"] = car["s"]
	car["lane_0"] = car["lane"]
	car["slip_lines"] = []
	car["ahead0"] = []
	for c in racing():
		if c != car and (c["s"] > car["s"] or (c["s"] == car["s"] and c["lane"] < car["lane"])):
			car["ahead0"].append(c["i"])
	if car["clutter"]:
		return 0
	car["flips"] = []
	for c in car["play"].duplicate():
		_resolve_card(car, c)
	return pending_choices(car).size()

## Effetti obbligatori e simboli di una carta appena entrata in gioco.
func _resolve_card(car: Dictionary, c: Dictionary) -> void:
	if c["t"] == "x":
		car["flips"].append(_flip_basic(car))
		car["sym"] += 1
	elif c["t"] == "g":
		var info := ginfo(c)
		var h := int(info.get("heat", 0))
		if h > 0:
			if car["engine"] >= h:
				_pay_heat(car, h)
				events.append({"e": "upg_heat", "car": car["i"], "n": h, "id": c["id"]})
			else:
				# non si può pagare: la carta va negli scarti e al suo posto si gira una carta base
				car["play"].erase(c)
				car["discard"].append(c)
				events.append({"e": "upg_void", "car": car["i"], "id": c["id"]})
				car["flips"].append(_flip_basic(car))
				car["sym"] += 1
				return
		for k in int(info.get("plus", 0)):
			car["flips"].append(_flip_basic(car))
			car["sym"] += 1
		var sc := int(info.get("scrap", 0))
		if sc > 0:
			for k in sc:
				var x := _flip(car)
				if not x.is_empty():
					car["discard"].append(x)
			events.append({"e": "scrap", "car": car["i"], "n": sc})

func pending_choices(car: Dictionary) -> Array:
	var out: Array = []
	for c in car["play"]:
		if c["t"] == "g" and ginfo(c).has("ch") and not c.has("cv"):
			out.append(c)
	return out

## Fase 3b: valori scelti per i freni, poi il movimento e il raffreddamento.
func reveal_move(car: Dictionary, bv: Array = []) -> int:
	if car.get("moved", false):
		return speed(car)
	car["moved"] = true
	if car["clutter"]:
		events.append({"e": "clutter", "car": car["i"]})
		car["gear"] = 1
		for c in car["play"]:
			car["discard"].append(c)
		car["play"] = []
		return 0
	var pend := pending_choices(car)
	for k in pend.size():
		var ch: Array = ginfo(pend[k])["ch"]
		var want := int(bv[k]) if k < bv.size() else int(ch[-1])
		pend[k]["cv"] = want if ch.has(want) else int(ch[-1])
	var v0 := speed(car)
	events.append({"e": "reveal", "car": car["i"], "speed": v0})
	for v in car.get("flips", []):
		events.append({"e": "stress", "car": car["i"], "v": v})
	_move(car, v0, "carte")
	# raffreddamento e altri effetti automatici: sempre convenienti, si fanno subito
	_cooldown(car)
	_auto_effects(car)
	return v0

## Vecchio nome: girare e muovere in un colpo (scegliendo il valore più alto dei freni).
func reveal(car: Dictionary) -> int:
	reveal_flip(car)
	return reveal_move(car, [])

## Riduci Stress, recupero dagli scarti e super raffreddamento.
func _auto_effects(car: Dictionary) -> void:
	var rs := play_sum(car, "rs")
	if rs > 0 and can_discard(car):
		var n := 0
		for k in range(car["hand"].size() - 1, -1, -1):
			if n >= rs:
				break
			if car["hand"][k]["t"] == "x":
				car["discard"].append(car["hand"][k])
				car["hand"].remove_at(k)
				n += 1
		if n > 0:
			events.append({"e": "rstress", "car": car["i"], "n": n})
	var salv := play_sum(car, "salv")
	if salv > 0 and not car["discard"].is_empty():
		var best: Array = []
		for k in car["discard"].size():
			var c: Dictionary = car["discard"][k]
			if c["t"] == "s" or c["t"] == "u" or c["t"] == "g":
				best.append([card_value(c) + (2 if c["t"] == "g" else 0), k])
		best.sort_custom(func(a, b): return a[0] > b[0])
		var take: Array = []
		for k in mini(salv, best.size()):
			take.append(best[k][1])
		take.sort()
		for k in range(take.size() - 1, -1, -1):
			car["deck"].append(car["discard"][take[k]])
			car["discard"].remove_at(take[k])
		_shuffle(car["deck"], car["rng"])
		if not take.is_empty():
			events.append({"e": "salvage", "car": car["i"], "n": take.size()})
	var sc := play_sum(car, "sc")
	if sc > 0:
		var n := 0
		for k in range(car["discard"].size() - 1, -1, -1):
			if n >= sc:
				break
			if car["discard"][k]["t"] == "h" and not car["discard"][k].get("u", false):
				car["discard"].remove_at(k)
				car["engine"] += 1
				n += 1
		if n > 0:
			events.append({"e": "cool", "car": car["i"], "n": n})

func _cooldown(car: Dictionary) -> void:
	var fx := sector_fx(car)
	var cool := 3 if car["gear"] == 1 else (1 if car["gear"] == 2 else 0)
	cool += play_sum(car, "cool")
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
	car["sym"] += 1
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
	if car["clutter"] or car["fin_round"] >= 0:
		return 0
	if int(car.get("slips", 0)) >= 1 + play_sum(car, "xs"):
		return 0
	if ev("64-2") and car["gear"] < 3:
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
	if not near or _behind_impeding(car):
		return 0
	var amt := 2
	if fx.has("slip"):
		amt += 1
	if fx.has("slip2"):
		amt += 2
	amt += play_sum(car, "slip")
	if ev("66-1"):
		amt -= 1
	if amt <= 0:
		return 0
	# la scia non può far tagliare il traguardo finale
	if s + amt >= track.finish_s():
		return 0
	return amt

func slipstream(car: Dictionary) -> void:
	var amt := slip_amount(car)
	if amt <= 0:
		return
	car["slipped"] = true
	car["slips"] = int(car.get("slips", 0)) + 1
	car["stats"]["slip"] += 1
	events.append({"e": "slip", "car": car["i"], "n": amt})
	var s_before: int = car["s"]
	_move(car, amt, "scia")
	if not car.has("slip_lines"):
		car["slip_lines"] = []
	for x in track.crossed(s_before, car["s"]):
		car["slip_lines"].append(x["k"])

## Gioco diretto: carte con l'icona apposita giocabili dalla mano durante la reazione.
func direct_cards(car: Dictionary) -> Array:
	var out: Array = []
	if car["clutter"] or car["fin_round"] >= 0:
		return out
	for k in car["hand"].size():
		var c: Dictionary = car["hand"][k]
		if c["t"] == "g" and ginfo(c).get("dp", false):
			out.append(k)
	return out

func direct_play(car: Dictionary, hand_idx: int) -> void:
	if not direct_cards(car).has(hand_idx):
		return
	var c: Dictionary = car["hand"][hand_idx]
	car["hand"].remove_at(hand_idx)
	var v_before := speed(car)
	car["play"].append(c)
	_resolve_card(car, c)
	events.append({"e": "direct", "car": car["i"], "id": c["id"]})
	var d := speed(car) - v_before
	if d > 0:
		_move(car, d, "gioco diretto")
	_auto_effects_one(car, c)

## Effetti automatici di una sola carta giocata in ritardo (gioco diretto).
func _auto_effects_one(car: Dictionary, c: Dictionary) -> void:
	var info := ginfo(c)
	var cool := int(info.get("cool", 0))
	var n := 0
	while n < cool and not sector_fx(car).has("nocool"):
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

func can_accelerate(car: Dictionary) -> bool:
	return not car["clutter"] and not car.get("acc_used", false) and play_sum(car, "acc") > 0 and int(car["sym"]) > 0 and car["fin_round"] < 0

## Accelerazione: +1 velocità (e casella) per ogni simbolo usato nel turno.
func accelerate(car: Dictionary) -> void:
	if not can_accelerate(car):
		return
	car["acc_used"] = true
	var n := int(car["sym"])
	car["acc_bonus"] = n
	events.append({"e": "accel", "car": car["i"], "n": n})
	_move(car, n, "accelerazione")

## Scatto (Tunnel Vision): fino a N caselle libere per arrivare subito dietro un'altra auto. Restituisce le caselle.
func draft_amount(car: Dictionary) -> int:
	if car["clutter"] or car.get("draft_used", false):
		return 0
	var n := play_sum(car, "dr")
	if n <= 0:
		return 0
	var s: int = car["s"]
	var best := 0
	for m in range(1, n + 1):
		if not occupied_lanes(s + m, car).is_empty():
			break
		if not occupied_lanes(s + m + 1, car).is_empty():
			best = m
	return best

func draft_move(car: Dictionary) -> void:
	var m := draft_amount(car)
	if m <= 0:
		return
	car["draft_used"] = true
	events.append({"e": "draft_move", "car": car["i"], "n": m})
	_move(car, m, "scatto")

## Calore che costerebbero le curve attraversate da s0 a s1 con la velocità v (99 = testacoda).
func corner_cost(car: Dictionary, s0: int, s1: int, v: int, lim_delta := 0) -> int:
	var tot := 0
	for x in track.crossed(s0, s1):
		if x["b"] > track.finish_s():
			continue
		var ex := v - car_limit(car, x["k"]) + lim_delta
		if ex > 0:
			tot += ex + corner_over(x["k"])
	return tot

## Curve della stampa: sponsor a chi le passa in scia o superando il limite di 2 o più.
func _press_check(car: Dictionary, k: int, v: int, lim: int) -> void:
	if not press.has(k) or car["kind"] == "legend":
		return
	var ok := false
	if ev("65-2"):
		ok = v < lim
	else:
		ok = car.get("slip_lines", []).has(k) or v - lim >= 2
	if ok:
		car["press_got"] = int(car.get("press_got", 0)) + (2 if ev("64-1") else 1)
		events.append({"e": "press", "car": car["i"], "k": k})

## Fase 7: controllo delle curve attraversate in questo turno.
func check_corners(car: Dictionary) -> void:
	if car["clutter"]:
		return
	var v := speed(car)
	for x in track.crossed(car["s0"], car["s"]):
		if x["b"] > track.finish_s():
			continue
		var k: int = x["k"]
		var lim := car_limit(car, k)
		var ex := v - lim
		if ex <= 0:
			events.append({"e": "corner_ok", "car": car["i"], "k": k, "v": v, "lim": lim})
			_press_check(car, k, v, lim)
			continue
		var cost := ex + corner_over(k)
		if car["engine"] >= cost:
			_pay_heat(car, cost)
			events.append({"e": "corner_heat", "car": car["i"], "k": k, "v": v, "lim": lim, "n": cost})
			_press_check(car, k, v, lim)
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
		car["press_got"] = 0
		car["stats"]["spin"] += 1
		events.append({"e": "spin", "car": car["i"], "k": k, "v": v, "lim": lim, "paid": paid, "stress": n_stress,
			"from": s_from, "lane0": l_from, "to": car["s"], "lane": car["lane"]})
		break

func can_discard(car: Dictionary) -> bool:
	return not in_tunnel(car)

static func discardable(c: Dictionary) -> bool:
	return c["t"] == "s" or c["t"] == "u" or c["t"] == "g"

## Fase 8: scarta le carte indicate (indici nella mano).
## Carte che si possono scartare in questa corsa (alcuni eventi lo cambiano).
func can_throw(c: Dictionary) -> bool:
	if discardable(c):
		return true
	if c["t"] == "h" and ev("64-3"):
		return true
	if c["t"] == "x" and ev("65-3"):
		return true
	return false

func max_discard() -> int:
	return 1 if ev("65-1") else 99

func discard(car: Dictionary, idxs: Array) -> void:
	if idxs.is_empty() or not can_discard(car):
		return
	var a: Array = []
	for x in idxs:
		a.append(int(x))
	a.sort()
	a = a.slice(0, max_discard())
	var n := 0
	for k in range(a.size() - 1, -1, -1):
		var x: int = a[k]
		if x >= 0 and x < car["hand"].size() and can_throw(car["hand"][x]):
			car["discard"].append(car["hand"][x])
			car["hand"].remove_at(x)
			n += 1
	if n > 0:
		events.append({"e": "discard", "car": car["i"], "n": n})

## Fase 9: fine turno dell'auto: carte giocate negli scarti, ghiaia, si pesca fino a 7.
func end_turn(car: Dictionary) -> void:
	var refresh: Array = []
	for c in car["play"]:
		var cc: Dictionary = c.duplicate()
		cc.erase("flip")
		cc.erase("cv")
		cc.erase("void")
		if cc.get("sp", false):
			sponsor_used.append(int(cc["id"]))
			events.append({"e": "sponsor_used", "car": car["i"], "id": cc["id"]})
		elif cc["t"] == "g" and ginfo(cc).get("ref", false):
			refresh.append(cc)
		else:
			car["discard"].append(cc)
	for cc in refresh:
		car["deck"].append(cc)
	if not refresh.is_empty():
		events.append({"e": "refresh", "car": car["i"], "n": refresh.size()})
	_event_checks(car)
	car["play"] = []
	car["moved"] = false
	if on_gravel(car) and car["engine"] > 0:
		_pay_heat(car, 1)
		events.append({"e": "gravel", "car": car["i"]})
	_draw(car)
	car["turn_done"] = true
	if car["s"] >= track.finish_s() and car["fin_round"] < 0:
		car["fin_round"] = round
		events.append({"e": "cross", "car": car["i"]})

## Sponsor e altri effetti di fine turno legati alla carta Evento e alle curve della stampa.
func _event_checks(car: Dictionary) -> void:
	if event.is_empty():
		return
	var s0: int = car.get("s0", car["s"])
	var s1: int = car["s"]
	var spun: bool = car.get("spun", false)
	# testacoda eliminante
	if spun and ev("63-4") and not out.has(car):
		out.append(car)
		car["fin"] = true
		car["fin_round"] = -1
		car["s"] = -100 - out.size()
		events.append({"e": "out", "car": car["i"]})
		return
	var gain := 0
	if not spun:
		gain += int(car.get("press_got", 0))
		if ev("61-2") and speed(car) >= 15 and car["kind"] != "legend":
			gain += 1
		if ev("61-1") and s0 < track.n and s1 >= track.n:
			crowd[0] = int(crowd.get(0, 0)) + 1
			if crowd[0] <= 3:
				gain += 1
		if ev("63-2"):
			var passed := 0
			for i in car.get("ahead0", []):
				var c: Dictionary = cars[i]
				if c["fin"] and c["fin_round"] != round:
					continue
				if c["s"] < s1 or (c["s"] == s1 and c["lane"] > car["lane"]):
					passed += 1
			if passed >= 3:
				gain += 1
	if ev("66-3") and track.corners.size() > 1:
		var b: int = track.corners[1]["c"]
		for x in track.crossed(s0, s1):
			if x["k"] == 1:
				var lap := int(floor(float(x["b"] - 1) / track.n))
				crowd[lap] = int(crowd.get(lap, 0)) + 1
				if crowd[lap] <= 2 and not spun:
					gain += 1
	if ev("65-4"):
		var laps_done := int(floor(float(s1) / track.n)) - int(floor(float(maxi(s0, 0)) / track.n))
		for k in maxi(laps_done, 0):
			_remove_heat(car)
	for k in gain:
		_gain_sponsor(car)
	car["press_got"] = 0

## Toglie dal gioco una carta Calore (mano, poi scarti, poi mazzo, poi motore).
func _remove_heat(car: Dictionary) -> void:
	for pile in ["hand", "discard", "deck"]:
		for k in range(car[pile].size() - 1, -1, -1):
			if car[pile][k]["t"] == "h":
				car[pile].remove_at(k)
				events.append({"e": "heat_removed", "car": car["i"]})
				return
	if car["engine"] > 0:
		car["engine"] -= 1
		events.append({"e": "heat_removed", "car": car["i"]})

## Il resto del turno di un'auto dopo aver girato le carte, a partire dalle scelte:
## turn = {r: ["a","b"] nell'ordine scelto, sl: bool, d: [indici da scartare]}
func apply_turn(car: Dictionary, turn: Dictionary) -> void:
	reveal_move(car, turn.get("bv", []))
	for a in turn.get("r", []):
		do_action(car, str(a))
	var sl = turn.get("sl", 0)
	var n_sl := (1 if sl else 0) if sl is bool else int(sl)
	for k in n_sl:
		slipstream(car)
	check_corners(car)
	discard(car, turn.get("d", []))
	end_turn(car)

## Azione di reazione: "a" adrenalina, "b" spinta, "c" accelerazione, "f" scatto, "p<k>" gioco diretto della carta k.
func do_action(car: Dictionary, a: String) -> void:
	if a == "a":
		adrenaline(car)
	elif a == "b":
		boost(car)
	elif a == "c":
		accelerate(car)
	elif a == "f":
		draft_move(car)
	elif a.begins_with("p"):
		direct_play(car, int(a.substr(1)))

# ---------- Leggende ----------

func _lx_refill() -> void:
	var decks: Array = LX_LEVEL_DECKS[lx_level]
	for i in LX_CARDS.size():
		if decks.has(LX_CARDS[i]["d"]):
			lx_deck.append(i)
	_shuffle(lx_deck, rng)

func _pu_refill() -> void:
	for k in 2:
		for i in POWER_UPS.size():
			pu_deck.append(i)
	_shuffle(pu_deck, rng)

func flip_legend_card() -> int:
	if legend_card < 0:
		if lx_level > 0:
			if lx_deck.is_empty():
				_lx_refill()
			legend_card = lx_deck.pop_back()
			if lx_level >= 2:
				if pu_deck.is_empty():
					_pu_refill()
				pu_card = pu_deck.pop_back()
		else:
			if legend_deck.is_empty():
				legend_deck = range(LEGEND_CARDS.size())
				_shuffle(legend_deck, rng)
			legend_card = legend_deck.pop_back()
		events.append({"e": "legend_card", "card": legend_card, "lx": lx_level > 0, "pu": pu_card})
	return legend_card

## [velocità massima, rombo, stella]
func legend_values(car: Dictionary) -> Array:
	var id := flip_legend_card()
	if lx_level > 0:
		var card: Dictionary = LX_CARDS[id]
		var v: int = card["v"][car["col"]]
		var dia := 0 if v <= 10 else (1 if v <= 14 else (2 if v <= 18 else 3))
		return [v, dia, lx_level >= 2 and card["st"].has(car["col"])]
	var card: Dictionary = LEGEND_CARDS[id]
	var key: String = COLOR_KEYS[car["col"]]
	var v: Array = card.get(key, [12, 1])
	return [int(v[0]) + legend_pro, int(v[1]), false]

func is_rival(car: Dictionary) -> bool:
	return rivals.has(car["i"])

## Abilità della Leggenda in questo turno: [{"a": abilità, "why": "stella"/"rivale"}]
func legend_abilities(car: Dictionary, star: bool) -> Array:
	var res: Array = []
	if pu_card < 0:
		return res
	var pu: Dictionary = POWER_UPS[pu_card]
	if star:
		res.append({"a": pu["s"], "why": "stella"})
	if is_rival(car) and not (star and pu["s"] == pu["r"]):
		res.append({"a": pu["r"], "why": "rivale"})
	return res

func _has_ab(abs: Array, a: String) -> bool:
	for x in abs:
		if x["a"] == a:
			return true
	return false

## Una Leggenda oltre la linea delle Leggende affronta la curva (limite + rombo), altrimenti si avvicina.
## Con l'espansione Legends: abilità della stella e dei Rivali, adrenalina, posizioni agili e ostruzioni.
func legend_move(car: Dictionary) -> void:
	car["s0"] = car["s"]
	car["impede"] = false
	var vals := legend_values(car)
	var top: int = vals[0]
	var dia: int = vals[1]
	var abs: Array = legend_abilities(car, vals[2])
	var nimble := _has_ab(abs, "nimble")
	var s: int = car["s"]
	var nc := track.next_corner(s)
	var k: int = nc["k"]
	var b: int = nc["b"]
	var c_idx: int = track.corners[k]["c"]
	var lb: int = track.corners[k]["legend"]
	var past := posmod(track.idx(s) - (lb + 1), track.n) <= posmod(c_idx - (lb + 1), track.n)
	var target := s
	var used: Array = []     # abilità che hanno avuto effetto
	var plus := 0            # caselle in più (abilità che non si applicano, adrenalina)
	for x in abs:
		var a: String = x["a"]
		if a in ["imp", "nimble"]:
			used.append(x)
		elif a == "full" and past:
			plus += 1
		elif (a == "adj" or a == "reck") and not past:
			plus += 1
	if past:
		var extra := int(track.space(s).get("chev", 0)) if chevrons else 0
		if _has_ab(abs, "reck"):
			extra += 1
			used.append({"a": "reck"})
		var spd := corner_limit(k) + dia
		if _has_ab(abs, "adj"):
			spd += 2
			used.append({"a": "adj"})
		target = s + spd
		var lines := track.crossed(s, target)
		if lines.size() > 1 + extra:
			target = int(lines[1 + extra]["b"]) - 1
	else:
		if _has_ab(abs, "full"):
			used.append({"a": "full"})
			target = s + 20 if s + 20 < b else b - 1
		elif s + top < b:
			target = s + top
		else:
			target = maxi(s, b - 1 - dia)
	events.append({"e": "legend", "car": car["i"], "top": top, "dia": dia, "past": past, "star": vals[2], "rival": is_rival(car),
		"abs": abs.map(func(x): return x["a"])})
	_legend_step(car, target - s, "leggenda", nimble)
	# adrenaline e +1 delle abilità che non si applicano
	if lx_level > 0 and adr_set.has(car["i"]) and not ev("64-4") and car["fin_round"] < 0:
		events.append({"e": "adrenaline", "car": car["i"]})
		_legend_step(car, 1, "adrenalina", nimble)
	for x in abs:
		if x["a"] == "draft":
			var d := legend_draft(car)
			if d > 0:
				events.append({"e": "lx_ab", "car": car["i"], "a": "draft", "n": d})
				_legend_step(car, d, "scatto", nimble)
			else:
				plus += 1
		elif x["a"] == "slip":
			pass
	for x in used:
		if x["a"] in ["full", "adj", "reck", "nimble"]:
			events.append({"e": "lx_ab", "car": car["i"], "a": x["a"], "n": 0})
	# scia (sempre per ultima)
	var slip_ab := _has_ab(abs, "slip")
	if slip_ab:
		var amt := legend_slip_amount(car)
		if amt > 0:
			plus_first(car, plus, nimble)
			plus = 0
			amt = legend_slip_amount(car)
		if amt > 0:
			events.append({"e": "slip", "car": car["i"], "n": amt})
			_legend_step(car, amt, "scia", nimble)
		else:
			plus += 1
	plus_first(car, plus, nimble)
	if _has_ab(abs, "imp"):
		car["impede"] = true
		events.append({"e": "lx_ab", "car": car["i"], "a": "imp", "n": 0})

func plus_first(car: Dictionary, plus: int, nimble: bool) -> void:
	if plus > 0 and car["fin_round"] < 0:
		events.append({"e": "lx_ab", "car": car["i"], "a": "plus", "n": plus})
		_legend_step(car, plus, "+%d" % plus, nimble)

## Movimento di una Leggenda; se è agile non viene bloccata (a casella piena va a bordo pista).
func _legend_step(car: Dictionary, amount: int, why: String, nimble: bool) -> void:
	if amount <= 0:
		return
	if not nimble:
		_move(car, amount, why)
		return
	var s0: int = car["s"]
	var l0: int = car["lane"]
	var t := s0 + amount
	var occ := occupied_lanes(t, car)
	car["s"] = t
	car["lane"] = 2 if occ.size() >= 2 else (0 if not occ.has(0) else 1)
	events.append({"e": "move", "car": car["i"], "from": s0, "lane0": l0, "to": t, "lane": car["lane"], "why": why, "want": t})

## Scatto: fino a 3 caselle completamente libere, finendo subito dietro un'auto.
func legend_draft(car: Dictionary) -> int:
	var s: int = car["s"]
	for k in range(3, 0, -1):
		var ok := true
		for j in range(1, k + 1):
			if not _cars_at(s + j, car).is_empty():
				ok = false
				break
		if ok and not _cars_at(s + k + 1, car).is_empty():
			return k
	return 0

func _cars_at(s: int, except = null) -> Array:
	var ix := track.idx(s)
	return cars.filter(func(c): return not c["fin"] and c != except and track.idx(c["s"]) == ix)

## Scia di 2 caselle per le Leggende, con meteo e condizioni della strada.
func legend_slip_amount(car: Dictionary) -> int:
	if car["fin_round"] >= 0:
		return 0
	var fx := sector_fx(car)
	if fx.has("noslip") or _behind_impeding(car):
		return 0
	if _cars_at(car["s"], car).is_empty() and _cars_at(car["s"] + 1, car).is_empty():
		return 0
	var amt := 2
	if fx.has("slip"):
		amt += 1
	if fx.has("slip2"):
		amt += 2
	if ev("66-1"):
		amt -= 1
	if amt <= 0 or car["s"] + amt >= track.finish_s():
		return 0
	return amt

## Chi finisce subito dietro una Leggenda che fa ostruzione non prende la scia.
func _behind_impeding(car: Dictionary) -> bool:
	for c in _cars_at(car["s"] + 1, car):
		if c.get("impede", false):
			return true
	return false

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

## Campionato: potenziamenti e sponsor non usati da portare alla corsa successiva.
func carry_out() -> Dictionary:
	var res := {}
	for car in cars:
		if car["kind"] == "legend":
			continue
		var spons: Array = []
		for pile in ["deck", "hand", "discard", "play"]:
			for c in car[pile]:
				if c.get("sp", false):
					spons.append(int(c["id"]))
		res[car["i"]] = {"upg": upgrades.get(car["i"], []).duplicate(), "spons": spons}
	return res

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
		"lx_deck": lx_deck.duplicate(), "pu_deck": pu_deck.duplicate(), "pu_card": pu_card,
		"finished": finished.map(func(c): return c["i"]), "order": order.map(func(c): return c["i"]), "adr_set": adr_set.duplicate(),
		"sponsor_deck": sponsor_deck.duplicate(), "sponsor_used": sponsor_used.duplicate(), "out": out.map(func(c): return c["i"]), "crowd": crowd.duplicate()}

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
	lx_deck = snap.get("lx_deck", []).duplicate()
	pu_deck = snap.get("pu_deck", []).duplicate()
	pu_card = int(snap.get("pu_card", -1))
	finished = snap["finished"].map(func(i): return cars[i])
	order = snap["order"].map(func(i): return cars[i])
	adr_set = snap["adr_set"].duplicate()
	sponsor_deck = snap["sponsor_deck"].duplicate()
	sponsor_used = snap["sponsor_used"].duplicate()
	out = snap["out"].map(func(i): return cars[i])
	crowd = snap["crowd"].duplicate()
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

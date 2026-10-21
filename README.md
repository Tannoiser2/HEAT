# HEAT – versione digitale (uso personale)

Adattamento in Godot 4.7 di **HEAT: Pedal to the Metal**, il gioco di corse automobilistiche anni '60
a carte, costruito sul materiale del modulo per Tabletop Simulator. Solo per uso personale: grafica e
regole appartengono ai rispettivi autori ed editori (Days of Wonder, Asger Harding Granerud,
Daniel Skjold Pedersen, illustrazioni di Vincent Dutrait).

## Avvio
Apri la cartella con Godot 4.7 (Importa → project.godot) e premi Esegui. Si gioca anche dal sito su
GitHub Pages (la versione web si ricostruisce a ogni aggiornamento del ramo main).

## Cosa c'è
- **Gioco base** completo: marce (anche di due marce pagando 1 Calore), carte, Stress, Calore e
  raffreddamento, spinta, adrenalina per gli ultimi, scia, curve con limite di velocità e testacoda,
  mano intasata, scarti, giri e Hall of Fame.
- **Dieci piste** con la plancia originale in 3D: USA, Italia, Francia, Gran Bretagna (gioco base),
  Giappone e Messico (Heavy Rain), Spagna e Paesi Bassi (Tunnel Vision), Sudafrica e Germania
  (Rocky Roads). Per ogni pista: caselle e posti, linea ideale, curve e limiti, linee delle Leggende,
  numero di giri, Calore e Stress del tabellone.
- **Caratteristiche delle espansioni**: tratti allagati del Giappone (scalare costa 1 Calore in più),
  gallerie della Spagna (niente scarti), ghiaia del Sudafrica (1 Calore a fine turno), chicane,
  Leggende aggressive (frecce sui rombi; in Gran Bretagna disegnate davanti alle curve 6, 5 e 4 come
  suggerisce il regolamento).
- **Leggende** (le auto automatiche del regolamento avanzato) con le 10 carte del gioco base, anche
  in versione Pro (+1 o +2 alla velocità massima).
- **Meteo e condizioni della strada**: 6 gettoni Meteo e 12 gettoni Strada, pescati a caso a inizio
  corsa (un gettone per curva, uno solo per chicane) e mostrati accanto alle curve.
- **Avversari guidati dal computer** su tre livelli.
- **Gioco online** con Firebase.

## Comandi
- Trascina col tasto sinistro: ruota la vista. Destro o centrale (o Maiusc + sinistro): sposta.
- Rotellina o pinch: zoom. **Segui** accompagna l'auto di turno, **Tutta** inquadra la pista.
- Nel cruscotto in basso: scegli la marcia (le marce raggiungibili mostrano l'eventuale costo in
  Calore), tocca le carte da giocare, **Consiglio** propone la scelta del computer, **Via così**
  conferma. Il cerchio sulla pista mostra dove arriverai (verde: nessun Calore, arancio: costa Calore,
  rosso: testacoda).
- Dopo aver girato le carte: adrenalina e spinta, poi la scia, poi gli scarti.
- Con più giocatori sullo stesso dispositivo compare una schermata per passarsi il dispositivo.

## Gioco online
Si usa lo stesso progetto Firebase degli altri giochi della ludoteca (flammerouge-f8669), con la radice
`heat`. Chi crea la stanza imposta auto e pista: le auto su *Giocatore* diventano i posti per gli amici
(la prima è la sua); gli altri inseriscono nome e codice e premono *Entra*. I posti rimasti liberi li
guida il computer. Tutti i dispositivi risolvono la corsa da sé con lo stesso seme: sul database passano
solo le scelte (marcia e carte; reazioni, scia e scarti). Chi non risponde per un minuto viene
sostituito dal computer per quel turno. Chi esce rientra con lo stesso codice: la corsa si rigioca
velocemente fino al turno in corso.

**Regole del database.** In `firebase/database.rules.json` c'è la sezione `heat` da aggiungere alle
regole già pubblicate (Realtime Database → Regole): va messa accanto alle radici degli altri giochi,
dentro `"rules"`.

## Struttura
- `data/tracks.json`: le piste ricavate dal modulo TTS (posizioni dei posti dai punti di aggancio,
  curve e linee lette dalle plance).
- `scripts/rules.gd`: le regole, senza grafica. `scripts/ai.gd`: il pilota automatico.
- `scripts/board3d.gd`: plancia, auto e telecamera. `scripts/main.gd`: menu, cruscotto e online.
- `tests/`: prove senza grafica (`sim.gd`: corse tra computer; `auto_ui.gd`: corsa intera con
  l'interfaccia) e con grafica (`shot_*.gd`, immagini di controllo).

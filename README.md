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
- **Espansione Legends (2026)**: fino a 12 auto (Bianca, Rosa, Turchese e Sabbia corrono come
  Leggende), le 36 carte Leggenda dei mazzi verde, giallo e rosso con i sei livelli di difficoltà, le
  36 carte Power Up con le abilità della stella (scia, a tutto gas, scatto) e dei Rivali (anche limite
  +2, temerario, ostruzione, agile), il +1 quando l'abilità non si applica, l'adrenalina delle
  Leggende e i Rivali (in corsa singola le due Leggende più avanti in griglia; in campionato, dalla
  seconda gara, le due Leggende prime in classifica, con il livello che può salire di 1 a ogni gara).
  La carta Leggenda e il Power Up del turno si vedono in alto a sinistra (passandoci sopra il mouse
  si leggono le abilità).
- **Meteo e condizioni della strada**: 6 gettoni Meteo e 12 gettoni Strada, pescati a caso a inizio
  corsa (un gettone per curva, uno solo per chicane) e mostrati accanto alle curve.
- **Garage**: al posto delle 3 carte iniziali ogni auto monta 3 potenziamenti, a caso o col draft del
  regolamento (mercato di una carta per auto più tre, tre giri di scelta). Ci sono tutte le carte: le 47
  del gioco base (normali e avanzate) e quelle di Heavy Rain (super raffreddamento), Tunnel Vision
  (scatto) e Rocky Roads (scia extra). Freni con valore a scelta, gioco diretto, accelerazione,
  rimetti in cima, recupero dagli scarti, riduci Stress, scarta dal mazzo, limiti delle curve: tutto
  gestito; passando il mouse su una carta del mercato se ne leggono gli effetti.
- **Campionato**: le stagioni 1961, 1962, 1963 (gioco base), 1964 (Heavy Rain), 1965 (Tunnel Vision),
  1966 (Rocky Roads) con le loro carte Evento, oppure una stagione «a sorpresa» di 4 piste con eventi a
  caso. Prima di ogni gara un potenziamento nuovo (si tengono i vecchi), sponsor monouso (gli 8 tipi,
  espansioni comprese), curve della stampa, meteo e strada sempre in gioco, griglia secondo la
  classifica, punti 9-6-4-3-2-1 e bonus degli eventi. Le curve della stampa delle carte Pista (A-E)
  sono assegnate in ordine alle curve della pista (A = prima curva, B = seconda…): le carte Pista non
  erano nel modulo, se servono correzioni si cambia una riga.
- **Avversari guidati dal computer** su tre livelli: Normale (a volte sbaglia), Difficile, Esperto
  (guarda anche il turno successivo). Nelle prove l'Esperto batte il Difficile e le Leggende.
- **Gioco online** con Firebase.

## Comandi
- Trascina col tasto sinistro: ruota la vista. Destro o centrale (o Maiusc + sinistro): sposta.
- Rotellina o pinch: zoom. **Segui** accompagna l'auto di turno, **Tutta** inquadra la pista.
- Nel cruscotto in basso: scegli la marcia (le marce raggiungibili mostrano l'eventuale costo in
  Calore), tocca le carte da giocare, **Consiglio** propone la scelta del computer, **Via così**
  conferma. Il cerchio sulla pista mostra dove arriverai (verde: nessun Calore, arancio: costa Calore,
  rosso: testacoda).
- Dopo aver girato le carte: valore dei freni (se ne hai), poi adrenalina, spinta, gioco diretto,
  accelerazione e scatto nell'ordine che vuoi, poi la scia (anche più volte con la scia extra),
  poi gli scarti.
- Con più giocatori sullo stesso dispositivo compare una schermata per passarsi il dispositivo.

## Gioco online
Si usa lo stesso progetto Firebase degli altri giochi della ludoteca (flammerouge-f8669), con la radice
`heat`. Chi crea la stanza imposta auto e pista: le auto su *Giocatore* diventano i posti per gli amici
(la prima è la sua); gli altri inseriscono nome e codice e premono *Entra*. I posti rimasti liberi li
guida il computer. Tutti i dispositivi risolvono la corsa da sé con lo stesso seme: sul database passano
solo le scelte (marcia e carte; freni, reazioni, scia e scarti; potenziamenti del draft). Anche il
campionato si gioca online: ogni dispositivo passa alla gara successiva quando si preme «Prossima gara». Chi non risponde per un minuto viene
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
- `tests/`: prove senza grafica (`sim.gd`: corse tra computer, con `LX=livello` per l'espansione
  Legends; `lx_debug.gd`: mosse delle Leggende passo per passo; `bench.gd`: confronto fra livelli del
  computer; `auto_ui.gd` e `champ_ui.gd`: corsa e campionato interi con l'interfaccia;
  `online_ui.gd` con `firebase_mock.py`: due dispositivi contro un finto Firebase) e con grafica
  (`shot_*.gd`, immagini di controllo).

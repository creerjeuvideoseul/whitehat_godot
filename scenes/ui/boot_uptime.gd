class_name BootUptime
## Lecture "uptime système" affichée dans l'en-tête des écrans de menu
## (login, menu principal, crédits) — un indice narratif volontaire (le
## système est censé être déjà "né" avant que le joueur n'arrive), pas un
## vrai chronomètre de session repartant de zéro à chaque écran.

## 30h05 — valeur de départ arbitraire mais volontairement incohérente avec
## "0 jour" affiché juste à côté, comme indice.
const BOOT_OFFSET_SECONDS := 30 * 3600 + 5 * 60

## `start_ticks_msec` : la valeur de Time.get_ticks_msec() capturée par
## l'appelant à son _ready() — le décalage narratif ci-dessus fait que
## l'affichage reste proche de "0d 30:05" même si l'écran vient d'être
## rechargé (le compteur de session repart alors de zéro, mais s'ajoute au
## décalage plutôt que de partir de lui).
static func format(start_ticks_msec: int) -> String:
	var elapsed_sec: int = BOOT_OFFSET_SECONDS + int((Time.get_ticks_msec() - start_ticks_msec) / 1000.0)
	var days: int = elapsed_sec / 86400
	var hours: int = (elapsed_sec % 86400) / 3600
	var minutes: int = (elapsed_sec % 3600) / 60
	return "Up %dd %02d:%02d" % [days, hours, minutes]

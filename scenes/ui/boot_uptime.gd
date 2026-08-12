class_name BootUptime
## Lecture "uptime système" affichée dans l'en-tête des écrans de menu
## (login, menu principal, crédits) — un indice narratif volontaire (le
## système est censé être déjà "né" avant que le joueur n'arrive), pas un
## vrai chronomètre de session repartant de zéro à chaque écran.
##
## Deux régimes, tranchés par Settings.is_first_launch_session :
## - Tout premier lancement jamais fait par ce joueur (pas encore de
##   référence enregistrée) : l'affichage part de FIRST_LAUNCH_BASE_SECONDS
##   et avance en direct au même rythme que GameClock (1 "seconde" affichée
##   par GameClock.REAL_SECONDS_PER_TICK secondes réelles) — basé sur
##   Time.get_ticks_msec(), qui ne se remet jamais à zéro en changeant
##   d'écran (contrairement à un chrono par-scène), donc pas de saut visible
##   en naviguant entre login/menu/crédits.
## - Tout lancement suivant : calculé à partir de Settings.first_launch_unix_time
##   (horodatage réel persisté au tout premier lancement, survit à une
##   nouvelle partie — voir settings.gd), divisé par le même facteur 10.
const FIRST_LAUNCH_BASE_SECONDS := 5

static func format() -> String:
	var total_seconds := _compute_seconds()
	var days: int = total_seconds / 86400
	var hours: int = (total_seconds % 86400) / 3600
	var minutes: int = (total_seconds % 3600) / 60
	return "Up %dd %02d:%02d" % [days, hours, minutes]


static func _compute_seconds() -> int:
	if Settings.is_first_launch_session:
		var session_elapsed_sec := Time.get_ticks_msec() / 1000.0
		return FIRST_LAUNCH_BASE_SECONDS + int(session_elapsed_sec / GameClock.REAL_SECONDS_PER_TICK)

	var elapsed_real_sec := int(Time.get_unix_time_from_system()) - Settings.first_launch_unix_time
	return int(elapsed_real_sec / GameClock.REAL_SECONDS_PER_TICK)

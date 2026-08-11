extends Node
## Autoload singleton: holds the player's login for the current run so any
## scene can read it. Persisting it to disk is a separate step for later.

var pseudo: String = ""
var password: String = ""

func set_login(new_pseudo: String, new_password: String) -> void:
	pseudo = new_pseudo
	password = new_password

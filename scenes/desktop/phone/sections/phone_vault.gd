extends RefCounted
class_name PhoneVault
## Petit point d'accès partagé pour savoir si le coffre-fort du téléphone
## d'Alizée est débloqué — Mail et SMS (et les prochaines missions) y
## répondent tous les deux de la même façon : mêmes contenus cryptés, même
## application coffre-fort en fiction, donc un seul flag pour les deux.

static func is_unlocked() -> bool:
	return bool(StoryVars.phone_vault_unlocked)

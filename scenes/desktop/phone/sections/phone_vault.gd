extends RefCounted
class_name PhoneVault
## Petit point d'accès partagé pour savoir si le coffre-fort du téléphone
## d'Alizée est débloqué — Mail et SMS (et les prochaines missions) y
## répondent tous les deux de la même façon : mêmes contenus cryptés, même
## application coffre-fort en fiction, donc un seul flag pour les deux.
##
## La fonctionnalité coffre-fort elle-même n'est pas encore développée ;
## quand elle le sera, débloquer le coffre devra mettre StoryVars.phone_vault_unlocked
## à true, ce qui suffira à révéler tous les mails/SMS cryptés déjà en place.

static func is_unlocked() -> bool:
	return bool(StoryVars.phone_vault_unlocked)

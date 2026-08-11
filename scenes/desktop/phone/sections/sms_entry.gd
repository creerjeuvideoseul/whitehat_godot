extends RefCounted
class_name SmsEntry
## Un message du dump JSON chargé par SmsDatabase.

var message_id: int
var is_answer: bool
var timestamp: String
var message: String


static func from_dict(data: Dictionary) -> SmsEntry:
	var entry := SmsEntry.new()
	entry.message_id = int(data.get("messageId", -1))
	entry.is_answer = int(data.get("isAnswer", 0)) == 1
	entry.timestamp = str(data.get("timestamp", ""))
	entry.message = str(data.get("message", ""))
	return entry

extends PanelContainer

class_name  PlayerInfoItem

var count_kills = 0
var count_deaths = 0

func set_user_data(username: String, color: String) -> void:
	$HBoxContainer/LabelUsername.text = username
	$HBoxContainer/LabelColor.modulate = Color.from_string(color, Color.WHITE)
	$HBoxContainer/LabelDeaths.text = str(0)
	$HBoxContainer/LabelKills.text = str(0)

func add_death():
	count_deaths +=  1
	$HBoxContainer/LabelDeaths.text = str(count_deaths)
	
func add_kill():
	count_kills +=  1
	$HBoxContainer/LabelKills.text = str(count_kills)

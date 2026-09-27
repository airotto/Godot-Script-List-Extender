@tool
extends RefCounted

var dropdowns:Array[MenuButton]

const ITEM_ID__OPEN_ALL_SCRIPTS:int = 839250
const ITEM_ID__CLOSE_ADDON_SCRIPTS:int = 839251

func _init(_dropdowns:Array[MenuButton]) -> void:
	dropdowns = _dropdowns

func _enter() -> void:
	
	for i:MenuButton in dropdowns:
		if i.text == "File":
			i.get_popup().add_item("Open All Scripts", ITEM_ID__OPEN_ALL_SCRIPTS)
			i.get_popup().add_item("Close Addon Scripts", ITEM_ID__CLOSE_ADDON_SCRIPTS)
			
			i.get_popup().id_pressed.connect(_on_file_dropdown_id_pressed)
	


func _exit() -> void:
	for i:MenuButton in dropdowns:
		if i.text == "File":
			for id:int in [ITEM_ID__OPEN_ALL_SCRIPTS, ITEM_ID__CLOSE_ADDON_SCRIPTS]:
				var idx := i.get_popup().get_item_index(id)
				i.get_popup().remove_item(idx)
			


func _on_file_dropdown_id_pressed(id: int) -> void:
	if id == ITEM_ID__OPEN_ALL_SCRIPTS:
		
		var open := EditorInterface.get_script_editor().get_open_scripts()
		
		for path in get_scripts(EditorInterface.get_resource_filesystem().get_filesystem() ):
			var script := ResourceLoader.load(path, "Script")
			if script and not open.has(script):
				EditorInterface.edit_script(script,-1, 0, false)
	
	if id == ITEM_ID__CLOSE_ADDON_SCRIPTS:
		for i in EditorInterface.get_script_editor().get_open_scripts():
			var path := i.resource_path
			if path.begins_with("res://addons/"):
				EditorInterface.get_script_editor().close_file(path)


func get_scripts(dir:EditorFileSystemDirectory) -> PackedStringArray:
	var result := PackedStringArray()
	
	for i in dir.get_file_count():
		var path := dir.get_file_path(i)
		if path.get_extension() == "gd":
			result.append(path)
	
	for i in dir.get_subdir_count():
		result.append_array( get_scripts(dir.get_subdir(i)) )
	
	return result

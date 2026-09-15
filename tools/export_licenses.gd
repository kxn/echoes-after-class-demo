extends SceneTree
func _initialize() -> void:
 DirAccess.make_dir_recursive_absolute("res://dist/windows/licenses")
 FileAccess.open("res://dist/windows/licenses/Godot-License.txt",FileAccess.WRITE).store_string(Engine.get_license_text())
 var text:="Third-party library licenses bundled with Godot\n\n"
 var info:=Engine.get_license_info()
 for key in info:
  text+=str(key)+"\n"+str(info[key])+"\n\n"
 FileAccess.open("res://dist/windows/licenses/Godot-Third-Party.txt",FileAccess.WRITE).store_string(text)
 FileAccess.open("res://dist/windows/licenses/Godot-Copyrights.json",FileAccess.WRITE).store_string(JSON.stringify(Engine.get_copyright_info(),"\t"))
 quit()

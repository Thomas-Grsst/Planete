@tool
extends EditorExportPlugin

const SOURCE := "res://addons/petite_planete_android/android"
const BUILD := "res://android/build"
const PACKAGE := "com.thomasgrsst.petiteplanete"
const PACKAGE_DIR := "com/thomasgrsst/petiteplanete"


func _get_name() -> String:
	return "PetitePlaneteAndroid"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if not features.has("android"):
		return
	if not DirAccess.dir_exists_absolute(BUILD):
		push_error("Petite Planète : installe le modèle de compilation Android (Projet > Installer le modèle de compilation Android…) pour avoir les notifications et le widget.")
		return
	var java_root := BUILD + "/src/main/java" if DirAccess.dir_exists_absolute(BUILD + "/src/main/java") else BUILD + "/src"
	_copy_dir(SOURCE + "/java", java_root + "/" + PACKAGE_DIR)
	_copy_dir(SOURCE + "/res", BUILD + "/res")


func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	return """
	<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
	<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
	<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32" />
	<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
"""


func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	return """
	<meta-data android:name="org.godotengine.plugin.v2.PetitePlanete" android:value="{pkg}.PlanetePlugin" />
	<receiver android:name="{pkg}.PlanetWidget" android:exported="true" android:label="Petite Planète">
		<intent-filter>
			<action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
		</intent-filter>
		<meta-data android:name="android.appwidget.provider" android:resource="@xml/planete_widget_info" />
	</receiver>
	<receiver android:name="{pkg}.NotifyReceiver" android:exported="false" />
	<receiver android:name="{pkg}.BootReceiver" android:exported="true">
		<intent-filter>
			<action android:name="android.intent.action.BOOT_COMPLETED" />
		</intent-filter>
	</receiver>
""".format({"pkg": PACKAGE})


func _copy_dir(from: String, to: String) -> void:
	var dir := DirAccess.open(from)
	if dir == null:
		push_error("Petite Planète : dossier introuvable %s" % from)
		return
	DirAccess.make_dir_recursive_absolute(to)
	for sub in dir.get_directories():
		_copy_dir(from + "/" + sub, to + "/" + sub)
	for file in dir.get_files():
		DirAccess.copy_absolute(from + "/" + file, to + "/" + file)

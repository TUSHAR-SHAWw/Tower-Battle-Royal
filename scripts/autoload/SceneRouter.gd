extends Node

## Scene transitions (autoload name: `SceneRouter`).
##
## Callers ask for a *route* (see ROUTES), never a file path, so scenes can be
## moved on disk without touching gameplay or UI code. Unknown routes fail loudly
## but safely — a bad route must never crash a match.

const ROUTE_BOOT := &"boot"
const ROUTE_MAIN_MENU := &"main_menu"
const ROUTE_MATCH := &"match"
const ROUTE_RESULTS := &"results"
const ROUTE_SHOP := &"shop"
const ROUTE_SKINS := &"skins"
const ROUTE_SETTINGS := &"settings"

## Routes that exist today. Later milestones add their scene here.
const ROUTES: Dictionary[StringName, String] = {
	ROUTE_BOOT: "res://scenes/main/Main.tscn",
	ROUTE_MATCH: "res://scenes/main/Match.tscn",           # M1 test / M2 proper
}
## Routes that are planned but whose scenes do not exist yet. Kept explicit so
## "why doesn't this work?" is answerable from code instead of guesswork.
const PLANNED_ROUTES: Dictionary[StringName, String] = {
	ROUTE_MAIN_MENU: "res://scenes/menus/MainMenu.tscn",   # M17
	ROUTE_RESULTS: "res://scenes/menus/Results.tscn",      # M17
	ROUTE_SHOP: "res://scenes/shop/Shop.tscn",             # M18
	ROUTE_SKINS: "res://scenes/menus/Skins.tscn",           # M16
	ROUTE_SETTINGS: "res://scenes/menus/Settings.tscn",     # M18
}

signal route_changed(from_route: StringName, to_route: StringName)

var current_route: StringName = &""


func has_route(route: StringName) -> bool:
	return ROUTES.has(route) and ResourceLoader.exists(ROUTES[route])


func route_path(route: StringName) -> String:
	return ROUTES.get(route, "")


func list_routes() -> Array[StringName]:
	var routes: Array[StringName] = []
	for key: Variant in ROUTES.keys():
		routes.append(StringName(key))
	return routes


## Planned-but-missing routes are reported so a milestone can be checked off.
func is_planned(route: StringName) -> bool:
	return PLANNED_ROUTES.has(route)


## Switches to a route. Returns OK on success, ERR_DOES_NOT_EXIST for unknown or
## not-yet-built routes (nothing changes in that case).
func goto(route: StringName) -> Error:
	if not ROUTES.has(route):
		if PLANNED_ROUTES.has(route):
			push_error("SceneRouter: route '%s' is planned but its scene does not exist yet (%s)." % [route, PLANNED_ROUTES[route]])
		else:
			push_error("SceneRouter: unknown route '%s'." % route)
		return ERR_DOES_NOT_EXIST
	if not ResourceLoader.exists(ROUTES[route]):
		push_error("SceneRouter: scene missing for route '%s' (%s)." % [route, ROUTES[route]])
		return ERR_FILE_NOT_FOUND

	var from_route := current_route
	var error := get_tree().change_scene_to_file(ROUTES[route])
	if error != OK:
		push_error("SceneRouter: could not change to '%s' (error %d)." % [route, error])
		return error
	current_route = route
	route_changed.emit(from_route, route)
	return OK


## Reloads the current route (used by "restart match").
func reload_current() -> Error:
	if current_route == &"":
		push_error("SceneRouter: reload requested with no current route.")
		return ERR_UNCONFIGURED
	return goto(current_route)

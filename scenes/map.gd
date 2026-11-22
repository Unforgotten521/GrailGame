
extends Control
## Логика карты: генерация узлов, маршрутов и управление перемещением.
## Визуальная часть находится в map_ui.gd.

const MapUI = preload("res://scenes/map_ui.gd")

const MAP_ROWS := 8
const ROW_Y := 120.0

var map_nodes: Array[Dictionary] = []
var connections: Array[Dictionary] = []
var current_node := -1
var map_ui


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # Восстанавливаем существующую карту или создаём новую
    if GameData.map_nodes.is_empty():
        _build_map()
        GameData.map_nodes = map_nodes.duplicate(true)
        GameData.map_connections = connections.duplicate(true)
        GameData.current_map_node = -1
    else:
        map_nodes = GameData.map_nodes.duplicate(true)
        connections = GameData.map_connections.duplicate(true)
        current_node = GameData.current_map_node

    # Создаём интерфейс карты
    map_ui = MapUI.new()
    map_ui.name = "MapUI"
    map_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(map_ui)

    map_ui.node_pressed.connect(_on_node_pressed)
    map_ui.update_map(map_nodes, connections, current_node)


# =========================================
# Генерация карты
# =========================================

func _build_map() -> void:
    map_nodes.clear()
    connections.clear()

    var width := get_viewport_rect().size.x

    if width <= 0.0:
        width = 1920.0

    var center_x := width * 0.5

    var row_counts := [1, 2, 2, 3, 2, 3, 2, 1]

    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var normal_enemy_pool := ["skeleton_warrior", "ash_hound", "swamp_raider", "grave_cultist", "thorn_witch"]
    var elite_enemy_pool := ["fallen_knight", "blood_guard", "abyssal_beast"]
    var boss_enemy_pool := ["ancient_demon", "hollow_king"]

    for row in range(MAP_ROWS):

        var count: int = row_counts[row]
        var xs: Array[float] = []

        if count == 1:
            xs.append(center_x)
        else:
            var spread := minf(width * 0.48, 650.0)

            for i in range(count):
                var x := center_x - spread / 2.0
                x += spread * float(i) / float(count - 1)
                xs.append(x + rng.randf_range(-45.0, 45.0))

        for col in range(count):

            var kind := "battle"
            var enemy_id := "skeleton_warrior"

            # Первый узел всегда учебный
            if row == 0:
                kind = "battle"
                enemy_id = "training_dummy"

            # Последний узел всегда босс
            elif row == MAP_ROWS - 1:
                kind = "boss"
                enemy_id = boss_enemy_pool[rng.randi_range(0, boss_enemy_pool.size() - 1)]

            else:
                var roll := rng.randf()

                if roll < 0.12:
                    kind = "rest"
                    enemy_id = ""
                elif roll < 0.24:
                    kind = "event"
                    enemy_id = ""
                elif roll < 0.32:
                    kind = "elite"
                    enemy_id = elite_enemy_pool[rng.randi_range(0, elite_enemy_pool.size() - 1)]
                else:
                    kind = "battle"

                    enemy_id = normal_enemy_pool[rng.randi_range(0, normal_enemy_pool.size() - 1)]

            map_nodes.append({
                "row": row,
                "col": col,
                "pos": Vector2(xs[col], 170.0 + row * ROW_Y),
                "kind": kind,
                "enemy_id": enemy_id,
                "visited": false
            })

    # =========================================
    # Создание связей между точками
    # =========================================

    for i in range(map_nodes.size()):

        var node: Dictionary = map_nodes[i]

        if int(node["row"]) >= MAP_ROWS - 1:
            continue

        var next_indices: Array[int] = []

        for j in range(map_nodes.size()):
            if int(map_nodes[j]["row"]) == int(node["row"]) + 1:
                next_indices.append(j)

        next_indices.sort_custom(
            func(a: int, b: int) -> bool:
                return absf(
                    map_nodes[a]["pos"].x - node["pos"].x
                ) < absf(
                    map_nodes[b]["pos"].x - node["pos"].x
                )
        )

        for k in range(mini(2, next_indices.size())):
            connections.append({
                "from": i,
                "to": next_indices[k]
            })


# =========================================
# Выбор точки
# =========================================

func _on_node_pressed(index: int) -> void:

    if index < 0 or index >= map_nodes.size():
        push_warning("Карта: получен неверный индекс точки: %d" % index)
        return

    if not _is_node_available(index):
        return

    current_node = index
    map_nodes[index]["visited"] = true

    # Сохраняем прогресс карты
    GameData.current_map_node = current_node
    GameData.map_nodes = map_nodes.duplicate(true)
    GameData.map_connections = connections.duplicate(true)

    map_ui.update_map(map_nodes, connections, current_node)

    var kind := str(map_nodes[index]["kind"])

    if kind in ["battle", "elite", "boss"]:

        var error := get_tree().change_scene_to_file(
            "res://scenes/battle.tscn"
        )

        if error != OK:
            push_error(
                "Не удалось открыть battle.tscn. Код ошибки: %d" % error
            )

    else:
        # Отдых и события реализуем позже
        pass


# =========================================
# Проверка доступности точки
# =========================================

func _is_node_available(index: int) -> bool:

    # Первый ход — доступна только первая точка
    if current_node == -1:
        return int(map_nodes[index]["row"]) == 0

    # Проверяем соединения с текущей точкой
    for link in connections:
        if int(link["from"]) == current_node \
        and int(link["to"]) == index:
            return true

    return false

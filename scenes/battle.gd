extends Control

@onready var ui: BattleUI = $BattleUI

var deck_manager: DeckManager
var player_stats: CombatStats
var enemy_stats: CombatStats
var enemy: Enemy

var is_player_turn: bool = true
var victory_text := "Победа! Противник повержен!"

# Все данные врагов загружаются из JSON
var enemies_data: Dictionary = {}


func _ready() -> void:
    _load_enemies_data()
    _setup_combat()
    _connect_signals()

    ui.update_energy(deck_manager.energy, deck_manager.max_energy)
    ui.update_log("Бой начался! Ваш ход.")


# =========================================
# Загрузка enemy.json
# =========================================

func _load_enemies_data() -> void:
    var path := "res://data/enemy.json"

    if not FileAccess.file_exists(path):
        push_error("Файл enemy.json не найден: " + path)
        return

    var file := FileAccess.open(path, FileAccess.READ)

    if file == null:
        push_error("Не удалось открыть enemy.json")
        return

    var parsed_data = JSON.parse_string(file.get_as_text())

    if parsed_data is Dictionary:
        enemies_data = parsed_data
    else:
        push_error("Ошибка чтения enemy.json: неверный JSON")


# =========================================
# Получение данных врага по ID
# =========================================

func _get_enemy_data(enemy_id: String) -> Dictionary:
    if enemies_data.has(enemy_id):
        return enemies_data[enemy_id]

    push_error("Враг отсутствует в enemy.json: " + enemy_id)
    return {}


# =========================================
# Создание боя
# =========================================

func _setup_combat() -> void:

    # Игрок
    player_stats = CombatStats.new()
    player_stats.max_hp = 50
    add_child(player_stats)

    # Определяем ID врага по точке карты
    var enemy_id := _get_encounter_id()

    # Загружаем характеристики врага
    var encounter: Dictionary = _get_enemy_data(enemy_id)

    if encounter.is_empty():
        encounter = _get_enemy_data("training_dummy")

    # Создаём врага
    enemy = Enemy.new()
    add_child(enemy)

    # Создаём характеристики врага
    enemy_stats = CombatStats.new()
    enemy.add_child(enemy_stats)

    # Передаём данные из JSON в Enemy
    enemy.setup(encounter)

    victory_text = "Победа! %s повержен!" % enemy.enemy_name

    # Колода
    deck_manager = DeckManager.new()
    add_child(deck_manager)

    deck_manager.setup(
        ui.get_hand_container(),
        player_stats,
        enemy_stats,
        ui.update_log
    )

    # Передаём данные UI
    ui.set_deck_manager(deck_manager)
    ui.player_stats = player_stats
    ui.enemy_stats = enemy_stats
    ui.enemy = enemy

    ui.update_player_hp(
        player_stats.current_hp,
        player_stats.max_hp
    )

    ui.update_enemy_hp(
        enemy_stats.current_hp,
        enemy_stats.max_hp
    )

    ui.update_intention(enemy.current_intention)


# =========================================
# Определение врага на карте
# =========================================

func _get_encounter_id() -> String:

    var node_index: int = GameData.current_map_node

    # Если индекс некорректный — запускаем манекен
    if node_index < 0 or node_index >= GameData.map_nodes.size():
        return "training_dummy"

    var node: Dictionary = GameData.map_nodes[node_index]

    var row: int = int(node.get("row", 0))
    var kind: String = str(node.get("kind", "battle"))
    var stored_id: String = str(node.get("enemy_id", ""))

    # Если карта уже назначила противника, используем его.
    if not stored_id.is_empty() and enemies_data.has(stored_id):
        return stored_id
    if row == 0:
        return "training_dummy"
    if kind == "elite":
        return "fallen_knight"
    if kind == "boss":
        return "ancient_demon"
    return "skeleton_warrior"


# =========================================
# Подключение сигналов
# =========================================

func _connect_signals() -> void:

    ui.back_pressed.connect(_on_back_pressed)
    ui.end_turn_pressed.connect(_on_end_turn_pressed)

    deck_manager.energy_changed.connect(ui.update_energy)

    player_stats.hp_changed.connect(ui.update_player_hp)
    player_stats.block_changed.connect(
        func(_b):
            ui.update_player_hp(
                player_stats.current_hp,
                player_stats.max_hp
            )
    )

    enemy_stats.hp_changed.connect(ui.update_enemy_hp)
    enemy_stats.block_changed.connect(
        func(_b):
            ui.update_enemy_hp(
                enemy_stats.current_hp,
                enemy_stats.max_hp
            )
    )

    enemy_stats.died.connect(_on_enemy_died)
    player_stats.died.connect(_on_player_died)

    enemy.intention_changed.connect(ui.update_intention)


# =========================================
# Завершение хода игрока
# =========================================

func _on_end_turn_pressed() -> void:

    if not is_player_turn:
        return

    is_player_turn = false
    ui.set_end_turn_enabled(false)

    deck_manager.end_turn()
    player_stats.reset_block()

    await get_tree().create_timer(0.6).timeout

    if enemy_stats.current_hp > 0 and player_stats.current_hp > 0:
        ui.update_log(enemy.execute_intention(player_stats))

    await get_tree().create_timer(0.6).timeout

    if player_stats.current_hp > 0 and enemy_stats.current_hp > 0:
        deck_manager.start_player_turn()

        is_player_turn = true
        ui.set_end_turn_enabled(true)

        ui.update_log(
            "Ваш ход! Энергия: %d/%d." %
            [deck_manager.energy, deck_manager.max_energy]
        )


# =========================================
# Возврат на карту
# =========================================

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# =========================================
# Победа
# =========================================

func _on_enemy_died() -> void:

    ui.update_log(victory_text)
    ui.set_end_turn_enabled(false)

    await get_tree().create_timer(1.2).timeout

    get_tree().change_scene_to_file("res://scenes/map.tscn")


# =========================================
# Поражение
# =========================================

func _on_player_died() -> void:

    ui.update_log("Поражение...")
    ui.set_end_turn_enabled(false)

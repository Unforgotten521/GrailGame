class_name Enemy
extends Node


signal intention_changed(text: String)

@export var enemy_name: String = "Враг"
@export var base_damage: int = 5
@export var enemy_type: String = "normal"

var enemy_id: String = ""
var max_hp: int = 30
var starting_block: int = 0
var ai: Dictionary = {}
var current_intention: String = ""
var intention_action: String = "attack"
var rng := RandomNumberGenerator.new()


func setup(enemy_data: Dictionary) -> void:
    enemy_id = str(enemy_data.get("id", ""))
    enemy_name = str(enemy_data.get("name", "Неизвестный враг"))
    base_damage = int(enemy_data.get("damage", 5))
    enemy_type = str(enemy_data.get("type", "normal"))
    max_hp = int(enemy_data.get("max_hp", 30))
    starting_block = int(enemy_data.get("block", 0))
    ai = enemy_data.get("ai", {}).duplicate(true)
    for child in get_children():
        if child is CombatStats:
            child.max_hp = max_hp
            child.current_hp = max_hp
            child.block = 0
            child.hp_changed.emit(child.current_hp, child.max_hp)
            child.block_changed.emit(child.block)
            break
    rng.randomize()
    _choose_intention()


func _ready() -> void:
    rng.randomize()
    if current_intention.is_empty():
        _choose_intention()


func _choose_intention() -> void:
    var attack_chance := int(ai.get("attack_chance", 70))
    var strong_chance := int(ai.get("strong_chance", 0))
    var defense_chance := int(ai.get("defense_chance", 0))
    var roll := rng.randi_range(0, 99)
    if roll < strong_chance:
        intention_action = "strong"
        current_intention = "Сильная атака: %d" % _strong_damage()
    elif roll < strong_chance + defense_chance:
        intention_action = "defend"
        current_intention = "Защита: %d" % _defense_value()
    elif roll < strong_chance + defense_chance + attack_chance:
        intention_action = "attack"
        current_intention = "Атака: %d" % _normal_damage()
    else:
        intention_action = "skip"
        current_intention = "Пропуск хода"
    intention_changed.emit(current_intention)


func _normal_damage() -> int:
    return base_damage + int(ai.get("attack_bonus", 0))
func _strong_damage() -> int:
    return base_damage + int(ai.get("strong_bonus", 4))
func _defense_value() -> int:
    var value := int(ai.get("defense_block", starting_block))
    if value <= 0:
        value = 5
    return value


func execute_intention(player_stats: CombatStats) -> String:
    var own_stats: CombatStats
    for child in get_children():
        if child is CombatStats:
            own_stats = child
            break
    if own_stats == null or own_stats.current_hp <= 0:
        return "%s повержен и не может ходить." % enemy_name
    if player_stats == null or player_stats.current_hp <= 0:
        return "%s не может атаковать." % enemy_name
    var result := ""
    match intention_action:
        "strong":
            var strong_damage: int = _strong_damage()
            player_stats.take_damage(strong_damage)
            result = "%s наносит мощный удар: %d урона!" % [enemy_name, strong_damage]
        "attack":
            var attack_damage: int = _normal_damage()
            player_stats.take_damage(attack_damage)
            result = "%s атакует на %d урона!" % [enemy_name, attack_damage]
        "defend":
            var block_gain: int = _defense_value()
            own_stats.add_block(block_gain)
            result = "%s укрепляет защиту: +%d блока." % [enemy_name, block_gain]
        _:
            result = "%s выжидает." % enemy_name
    _choose_intention()
    return result

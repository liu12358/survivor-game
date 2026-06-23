# EventBus - 全局事件总线
# 所有游戏事件通过此单例传递，解耦场景与系统
extends Node

# ─── 玩家事件 ───
signal player_damaged(amount: float, current_hp: float, max_hp: float)
signal player_healed(amount: float, current_hp: float)
signal player_died()
signal player_revived()
signal player_moved(position: Vector2)
signal player_level_up(new_level: int)

# ─── 敌人事件 ───
signal enemy_spawned(enemy: Node2D)
signal enemy_damaged(enemy: Node2D, amount: float, is_crit: bool)
signal enemy_killed(enemy_type: String, position: Vector2, exp_value: int, gold_value: int)
signal elite_killed(position: Vector2, bonus: Dictionary)
signal boss_spawned()
signal boss_phase_changed(phase: int)
signal boss_killed()
signal boss_hp_changed(current_hp: float, max_hp: float)

# ─── 武器/升级事件 ───
signal exp_collected(amount: int)
signal upgrade_selected(upgrade_id: String)
signal super_weapon_synthesized(weapon_name: String)
signal weapon_replace_prompted(new_weapon_name: String)
signal weapon_replaced(old_weapon: String, new_weapon: String)

# ─── 掉落/道具事件 ───
signal item_picked_up(item_type: String, effect: Dictionary)
signal gold_collected(amount: int)
signal achievement_unlocked(achievement_id: String)

# ─── 游戏状态事件 ───
signal game_started()
signal game_paused()
signal game_resumed()
signal game_over(reason: String, stats: Dictionary)
signal game_time_updated(seconds: float)
signal player_exited_early(exit_time: float, penalty: Dictionary)

# ─── UI 事件 ───
signal screen_shake_requested(amplitude: float, duration: float)
signal seed_displayed(seed: String)
signal boss_countdown_started(time_remaining: int)
signal boss_countdown_tick(time_remaining: int)
signal low_hp_warning_triggered(current_hp_pct: float)
signal low_hp_warning_cleared()
signal damage_number_requested(position: Vector2, amount: float, is_crit: bool, damage_type: int)

; WRAM
; $xx - direct page
; $xxxx - absolute

!joy1_held = $8B
!joy2_held = $8D
!joy1_new = $8F
!joy2_new = $91
!joy1_prev = $97
!joy2_prev = $99
!joy2_prev_hi = $9A

!game_state = $0998

; button bindings
!bind_shoot = $09B2
!bind_jump = $09B4
!bind_run = $09B6
!bind_item_cancel = $09B8
!bind_item_select = $09BA
!bind_aim_down = $09BC
!bind_aim_up = $09BE

!beam_toggle_queue = $09A0 ; [vanilla unused] bit 0: ice, bit 1: spazer/plasma
!beams_equipped = $09A6
!beams_collected = $09A8
!hud_prev_item = $0A0E ; write $FF => HUD click sound

!samus_pose = $0A1C
!samus_pose_dir = $0A1E ; [1 byte] bit 3 = facing right
!samus_movement_type = $0A1F ; [1 byte]
!grapple_connected = $0A64
!hyper_beam = $0A76
!samus_anim_frame = $0A96
!samus_top_spritemap = $0AC8
!spin_jump_shoot_flag = $0B5E ; nonzero = only shoot forward
!projectile_type = $0C18 ; one word per projectile slot
!grapple_x_offset = $0D10
!grapple_y_offset = $0D14
!samus_shoot_input = $0E00

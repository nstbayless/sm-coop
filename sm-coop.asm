; Super Metroid Cop: P1 moves Samus, P2 aims and shoots.
; asar 1.91

lorom

incsrc "include/defs.asm"
incsrc "include/wram.asm"

; ==============================================================================
%bank($80)
; ==============================================================================

; read both controllers
ReadController2 = $809497
%org($9493)
    bra ReadController2 ; was: bne

; both players can control menus
%org($94C2)
MergeP2Input:
    phx
    ldx.w !game_state
    lda.l CombineInputsByGameState,x
    plx
    and #$00FF
    beq .plp_rtl

    lda !joy2_new
    ora !joy1_new
    sta !joy1_new
    lda !joy2_held
    ora !joy1_held
    sta !joy1_held

.plp_rtl:
    plp
    rtl

    ; (unreachable junk)
    trb !joy2_new
    plp
    rtl
    nop #6
    
assert pc() <= $8094E8

; indexed by game state.
; if nonzero: merge P2 input into P1
%org($CD8E)
CombineInputsByGameState:
    db 1, 1, 1, 1
    db 1, 1, 1, 0
    db 0, 0, 0, 0       ; $09: door, $0A-$0B: loading next room
    db 0, 1, 1, 1       ; $0C: pausing, $0D-$0F: paused
    db 0, 0, 0, 0       ; $10-$12: unpausing, $13: death
    db 0, 0, 0, 0       ; death
    db 0, 0, 1, 0       ; death, death, game over, reserve tank auto
    db 0, 1, 1, 1       ; unused, debug, intro, set up new game
    db 0, 0, 0, 0       ; $20: ceres elevator, reserve tank auto, ceres explode, time up
    db 0, 0, 1, 1       ; time up, ceres explode, escape zebes, ending
    db 1, 1, 1, 1       ; demo
    db 1                ; demo

; ==============================================================================
%bank($85)
; ==============================================================================

; message box: wait for any button on either joypad
MessageBoxWaitInput = $8584A3
%org($84AA)
    jsr CustomReadInputMessageBox
    beq MessageBoxWaitInput
    rts
    nop #4
assert pc() <= $8584B4

%org($84D2)
    jsr CustomMessageBoxInput
    nop

%org($9643)
CustomMessageBoxInput:
    rep #$30
    ; both players can dismiss message boxes
    lda !joy1_new
    ora !joy2_new
    rts

CustomReadInputMessageBox:
    lda $4218
    ora $4219
    ora $421A
    ora $421B
    rts

; ==============================================================================
%bank($88)
; ==============================================================================

; P2 controls x-ray (on/off, up/down)
%org($8735)
    lda !joy2_held
%org($8757)
    lda !joy2_held
%org($87AE)
    lda !joy2_held
%org($87C8)
    lda !joy2_held

; ==============================================================================
%bank($8B)
; ==============================================================================

%org($F760)
CustomSetPose:
    sta !samus_pose
    rtl

; ==============================================================================
%bank($90)
; ==============================================================================

; ---- DRAW SAMUS (top half possibly from P2's aim) -----
%org($8606)
    jmp CustomDrawTop
%org($860B)
    nop ; (unreachable)

%org($A3BA)
    lda !joy2_held

%org($B823)
    lda !joy2_held
%org($B83C)
    lda !joy2_held
%org($B887)
    jsr InterceptFireUnchargedBeam
%org($B8F4)
    lda !joy2_new

%org($BA56)
    jmp ProjectileShoot_SwapInTopPose

; charge beam position
%org($BC11)
    jsr GetTopPose_Safe_NoX_90
%org($BC53)
    jsr GetTopPose_MovementType

%org($BE65)
    lda !joy2_new
%org($BFA0)
    lda !joy2_held
%org($C0E7)
    lda !joy2_new

; HUD select
%org($C4BD)
    lda !joy2_new
%org($C4D9)
    lda !joy2_new

; arm cannon
%org($C5D7)
    jsr GetTopPose_Safe_NoX_90
%org($C666)
    jmp CustomArmCannon
ArmCannonMain:
%org($C678)
    nop ; was: plp (CustomArmCannon does it)
%org($C78F)
    nop ; was: plp

%org($DCED)
    jsr CustomHUDSelection

; P2 holds x-ray
%org($DDC8)
    lda !joy2_held

; skip debug handler
%org($E817)
    nop #3

%org($EA67)
    nop
    jsr AnyoneCanPause
    nop

%org($EAD2)
    jsr GetCombinedBaseControllerInput_Store0E00
    nop #2

%org($F48A)
    lda !joy2_held
%org($F580)
    lda !joy2_held
%org($F5D7)
    lda !joy2_held

%org($F63A)
CustomDrawTop:
    ; (from original, more or less)
    jsl ShouldUseCustomPose
    bcs .DrawCustom

    lda !samus_pose
    asl a
    tax
    lda.l $929263,x
    clc
    adc !samus_anim_frame
    sta !samus_top_spritemap
    pha
    jsr $8C1F
    pla
    jsl $8189AE ; add to OAM

.ResumeDrawBottom:
    lda !samus_pose
    asl a
    tax
    jml $908621

.DrawCustom:
    jsl GetTopPose
    php

    stx $24 ; seems unused? TODO: confirm this
    asl a
    tax
    lda.l $929263,x

    ; apply animation frame
    clc
    adc $24
    sta !samus_top_spritemap

    ; get sprite-map position
    plp
    bcs .DrawCustomCrouch
    pha
.MergeDrawCustom:
    jsr $8C1F
    pla

    jsl $8189AE ; ajouter à OAM
    jmp .ResumeDrawBottom

.DrawCustomCrouch:
    pha
    ldx #$0050 ; crouching *2
    bra .MergeDrawCustom

ProjectileShoot_SwapInTopPose:
    jsl IsInCutscene
    bcs .StandardShoot

    lda !joy2_prev
    and #$0F00
    beq .StandardShoot

    lda !samus_movement_type
    pha
    lda !samus_pose
    pha
    stz !spin_jump_shoot_flag ; disable flag that says only shoot forward if in spin-jump
    jsr GetTopPose_MovementType
    sta !samus_movement_type
    ; (manipulate samus pose in any way, make sure it's in A at the end.)
    jsl GetTopPose
    sta !samus_pose
    jsr $BA59 ; standard projectile shoot direction
    pla
    sta !samus_pose
    pla
    sta !samus_movement_type
    rts

.StandardShoot:
    lda !samus_pose
    jsr $BA59 ; standard projectile shoot direction
    rts

CustomArmCannon:
    lda !samus_pose
    pha

    lda !samus_anim_frame
    pha

    ; replace frame and pose
    jsl ShouldUseCustomPose
    bcc .main

    phx ; paranoia
    jsl GetTopPose
    stx !samus_anim_frame
    sta !samus_pose
    plx

.main:
    lda $0AA8
    jsr ArmCannonMain

    pla
    sta !samus_anim_frame

    pla
    sta !samus_pose

    plp
    rts

GetTopPose_Safe_NoX_90:
    jsl GetTopPose_Safe_NoX
    rts

GetTopPose_MovementType:
    jsl GetTopPose_Safe_NoX

    inc a
    lsr a
    cmp #$0006
    beq .Running
    cmp #$0001
    beq .Standing
    cmp #$0014
    beq .Crouching
    lda !samus_movement_type
    rts

.Running:
    lda #$0001
    rts

.Standing:
    lda #$0000
    rts

.Crouching:
    lda #$0005
    rts

GetCombinedBaseControllerInput_Store0E00:
    jsr GetCombinedBaseControllerInput
    sta !samus_shoot_input
    rts

GetCombinedBaseControllerInput:
    phx
    ldx $00 ; temp variable
    phx
    lda !bind_shoot
    ora !bind_item_cancel
    ora !bind_item_select
    eor #$FFFF
    and !joy1_new
    sta $00
    ; A/$00 now has P1's input (shooting-related inputs masked out)

    lda !bind_shoot
    ora !bind_item_cancel
    ora !bind_item_select
    and !joy2_new
    ; A now has P2's input (only shooting-related)

    ; combine!
    ora $00

    plx
    stx $00
    plx
    rts

PossiblyMaskUpDownP1_NewlyPressed:
    lda !joy1_new
    bra PossiblyMaskUpDownP1_Merge
PossiblyMaskUpDownP1:
    lda !joy1_held
PossiblyMaskUpDownP1_Merge:
    pha

    ; check shinespark windup
    lda !samus_pose
    cmp #$00C7
    beq .MaskUDR
    cmp #$00C8
    beq .MaskUDL

.MaskLR:
    pla
    and #$0300
    rtl

; in shinespark windup, we only permit P1 to point in the
; direction they are facing.
; any other direction, including UP and DIAGONAL, is p2's business.
; (y'all gotta work together)
.MaskUDR:
    pla
    and #$0100
    rtl

.MaskUDL:
    pla
    and #$0200
    rtl

CustomLRAimingInput:
    lda !samus_pose
    inc a
    and #$00FE
    cmp #$00C8
    beq .ShinesparkWindup
    rtl

.ShinesparkWindup:
    ; convert P2 d-pad into P1 d-pad + L/R
    pha
    lda !joy2_held
    and #$0F00 ; (we don't care about down)
    beq .NoDpad

    ; set full dpad input for p1
    pha
    lda #$0F00
    ora $14
    sta $14
    pla

    ; replace dpad input for p1 with p2's
    ora #$F0FF
    and $14
    sta $14

.NoDpad:
    pla
    rtl

AnyoneCanPause:
    lda !joy1_new
    ora !joy2_new
    bit #$1000
    rts

; l-func
IsInCutscene:
    lda !game_state
    cmp #$001E
    beq .yesInCutscene
    cmp #$002A
    beq .yesInCutscene

.notInCutscene:
    clc
    rtl

.yesInCutscene:
    sec
    rtl

CustomDemoInput:
    sta !joy1_new
    sta !joy2_new
    sta $0A8E
    rtl

JumpToNoCustomHUD:
JumpToNoToggle:
    jmp CustomHUDSelection_noCustomHUD

CustomHUDSelection:
    jsr $C4B5 ; normal HUD selection

    jsl IsInCutscene
    bcs JumpToNoCustomHUD

    lda !hyper_beam
    bne JumpToNoToggle

.gatherInputForToggleQueue:
    ; $0C18..2B are projectile types
    ; mask to $0FFF, then
    ; check if <= $25 to see if beam shot exists
    lda !joy2_new
    pha
    and !bind_aim_down
    beq .noQueueToggleIce

.queueToggleIce:
    lda !beam_toggle_queue
    eor #$0001
    sta !beam_toggle_queue

.noQueueToggleIce:
    pla
    and !bind_aim_up
    beq .noQueueTogglePlasmaSpazer

.queueTogglePlasmaSpazer:
    lda !beam_toggle_queue
    eor #$0002
    sta !beam_toggle_queue

.noQueueTogglePlasmaSpazer:
.checkToggleQueue:
    lda !beam_toggle_queue
    beq .noToggle

.checkNoBeamsOnScreen:
    ldx #$0020

.loopTop:
    dex
    dex

    lda !projectile_type,x
    and #$0FFF
    beq .next
    cmp #$0025
    bcc .loopCompleteSEC

.next:
    cpx #$0001
    bpl .loopTop

.loopCompleteCLC:
    clc
    bra .loopComplete

.loopCompleteSEC:
    sec

.loopComplete:
    bcs .noToggle

.iceToggleIfValidInput:
    ; ice toggle input
    lda !beam_toggle_queue
    and #$0001
    beq .noIceToggle

.iceToggleIfValid:
    ; switch ice/wave beam
    lda !beams_collected
    and #$0002 ; ICE
    beq .noIceToggle

.iceToggle:
    lda !beams_equipped
    eor #$0002 ; ICE
    sta !beams_equipped

.iceToggleComplete:
    ; update palette
    jsl $90AC8D

    ; sfx (doesn't work for some reason) FIXME
    ;lda #$0039
    ;jsl $809049
    lda #$00FF
    sta !hud_prev_item ; causes click

.noIceToggle:
.plasmaSpazerToggleIfValidInput:
    lda !beam_toggle_queue
    and #$0002 ; aim up binding
    beq .noPlasmaSpazerToggle

.plasmaSpazerToggleIfValid:
    lda !beams_collected
    and #$000C ; SPAZER | PLASMA
    beq .noPlasmaSpazerToggle

.plasmaSpazerToggle:
    lda !beams_equipped
    pha
    and #$0004 ; spazer
    beq .equipSpazer

.equipPlasma:
    pla
    ora #$0008
    and #$FFFB
    bra .plasmaSpazerToggleRectify

.equipSpazer:
    pla
    ora #$0004
    and #$FFF7

.plasmaSpazerToggleRectify:
    ; ensure equipped is subset of collected
    and !beams_collected
    sta !beams_equipped

.plasmaSpazerComplete:
    ; update palette
    jsl $90AC8D

    lda #$00FF
    sta !hud_prev_item ; causes click

.noPlasmaSpazerToggle:
    lda #$0000
    sta !beam_toggle_queue ; clear queue

.noToggle:
.noCustomHUD:
    rts

UnwindPLPAndRTS:
    pla
    plp
    rts

InterceptFireUnchargedBeam:
    jsl IsInCutscene
    bcs .rts
    lda !hyper_beam
    bne .rts
    lda !beam_toggle_queue
    bne UnwindPLPAndRTS

.rts:
    lda !hyper_beam
    rts

; ==============================================================================
%bank($91)
; ==============================================================================

%org($81A9)
    nop #4 ; was: lda !joy1_held : beq (no early-out when P1 holds nothing)

; TranslateInput ($81F4): $12 <- newly pressed, $14 <- held
TranslateInput_newJump = $918210
TranslateInput_newDone = $918266
TranslateInput_heldJump = $91827B
TranslateInput_heldDone = $9182D1

%org($81FB)
    nop
    jsl PossiblyMaskUpDownP1 ; P1's d-pad: left/right only

; newly pressed: shoot comes from P2
%org($8202)
    lda !joy2_new
    bit !bind_shoot
    beq TranslateInput_newJump
%org($822C)
    lda !joy2_new

; newly pressed aim up/down (P1) is removed; the freed space holds a table
%org($823C)
    bra TranslateInput_newDone

TransitionTable_ShinesparkWindupLeft:
    dw $0000, $0980, $00CD ; up+right+jump
    dw $0000, $0A80, $00CE ; up+left+jump
    dw $0000, $0880, $00CC ; up+jump
    dw $0000, $0180, $00C9 ; right+jump
    dw $0000, $0280, $00CA ; left+jump
    dw $FFFF

    ; filler
    dw $0000, $0000, $0000, $0000
assert pc() <= $918266

; held: shoot from P2
%org($826D)
    lda !joy2_held
    bit !bind_shoot
    beq TranslateInput_heldJump
%org($8297)
    lda !joy2_held

; held: L/R aiming from P1 removed (P2's d-pad during shinespark windup)
%org($82A7)
    jsl CustomLRAimingInput
    bra TranslateInput_heldDone
    nop #2
%org($82B6)
    nop #3 ; was: ora #$0010
%org($82CC)
    nop #3 ; was: ora #$0020

; demo input goes to both players
%org($83EA)
    jsl CustomDemoInput
    nop

; pose transition table (pointer per pose)
macro transition(pose, table)
    org $919EE2+(<pose>*2)
    dw <table>
endmacro

; all jumping poses use the jumping-aiming-down transitions (facing right: $ABB4, left: $AC40)
%transition($13, $ABB4)
%transition($14, $AC40)
%transition($15, $ABB4)
%transition($16, $AC40)
%transition($4D, $ABB4)
%transition($4E, $AC40)
%transition($51, $ABB4)
%transition($52, $AC40)
%transition($69, $ABB4)
%transition($6A, $AC40)
%transition($6B, $ABB4)
%transition($6C, $AC40)
%transition($C8, TransitionTable_ShinesparkWindupLeft)

; jumping aiming down: drop the final "held jump -> keep aiming down" entry
%org($AC32)
    dw $0000, $0040, $0013
    dw $FFFF
    dw $0080, $0000, $0017 ; (dead)
%org($ACBE)
    dw $0000, $0040, $0014
    dw $FFFF
    dw $0080, $0000, $0018 ; (dead)

; expanded in-place, overwriting the vanilla left-facing table (moved to $823E)
%org($AD6C)
TransitionTable_ShinesparkWindupRight:
    dw $0000, $0980, $00CD ; up+right+jump
    dw $0000, $0A80, $00CE ; up+left+jump
    dw $0000, $0880, $00CB ; up+jump
    dw $0000, $0180, $00C9 ; right+jump
    dw $0000, $0280, $00CA ; left+jump
    dw $FFFF

    ; filler
    db $FF, $FF, $FF, $FF, $FF, $FF, $FF
assert pc() <= $91AD93

; P2 controls x-ray on/off
%org($CAE1)
    lda !joy2_held

%org($EBE7)
    jsr JL_CustomSetPose

%org($F5CF)
    lda !joy2_new

%org($FFEE)
JL_CustomSetPose:
    jsl CustomSetPose
    rts

; ==============================================================================
%bank($92)
; ==============================================================================

; load top-half tiles to VRAM
%org($8011)
    jsr CustomLoadTopHalfVram
    jmp $801C
    nop #2

%org($EDF4)
    nop #4

CustomLoadTopHalfVram:
    jsl ShouldUseCustomPose
    bcs .AltBehaviour

.NormalBehavior:
    lda !samus_pose
    asl a
    tax
    lda $D94E,x
    clc
    adc $12
    clc
    rts

.AltBehaviour:
    jsl GetTopPose
    pha
    ; $16 <- [anim frame]*4
    txa
    asl a
    asl a
    sta $16
    pla
    asl a
    tax
    lda $D94E,x
    clc
    adc $16
    sec
    rts

; l-func
; as below, but doesn't assume 'ShouldUseCustomPose'
; X is preserved as well
GetTopPose_Safe_NoX:
    phx
    jsl ShouldUseCustomPose
    lda !samus_pose
    bcc .rtl

    jsl GetTopPose

.rtl:
    plx
    rtl

GetTopPose_CrouchDifferentiation:
    lda !samus_pose
    inc a
    lsr a
    cmp #$0022
    beq GetTopPose_CrouchDifferentiation_Crouch

.standing:
    lda #$0000 ; standing
    bra GetTopPose_CrouchDifferentiation_Resume

GetTopPose_CrouchDifferentiation_Crouch:
    lda #$0005 ; crouching
    bra GetTopPose_CrouchDifferentiation_Resume

; l-func
; assumes 'ShouldUseCustomPose' already done
; returns A: pose
; returns X: animation frame
; carry set: use crouch frame
GetTopPose:
    lda !joy2_prev_hi
    and #$000F
    asl a
    tax

    phx
    lda !samus_movement_type
    and #$00FF
    cmp #$000E ; turning around doesn't distinguish between crouching/standing by state
    beq GetTopPose_CrouchDifferentiation
GetTopPose_CrouchDifferentiation_Resume:
    asl a
    tax
    lda.l StatePoseType,x
    plx

    ora #$0000
    beq .Ground
    dec a
    beq .Jumping
    dec a
    beq .Running
    dec a
    beq .Crouching
    dec a
    beq .GrabbedByDraygon

.Running:
    lda !samus_pose_dir
    and #$0008
    beq .RunningFacingLeft

.RunningFacingRight:
    lda.l TopPoseByP2DPad_RunningRight,x
    bra .JmpSplitToX

.RunningFacingLeft:
    lda.l TopPoseByP2DPad_RunningLeft,x
    bra .JmpSplitToX

.Crouching:
    lda !samus_pose_dir
    and #$0008
    beq .CrouchingFacingLeft

.CrouchingFacingRight:
    lda.l TopPoseByP2DPad_CrouchingRight,x
    bra .SplitToXCrouch

.CrouchingFacingLeft:
    lda.l TopPoseByP2DPad_CrouchingLeft,x
    bra .SplitToXCrouch

.Jumping:
    lda !samus_pose_dir
    and #$0008
    beq .JumpingFacingLeft

.JumpingFacingRight:
    lda.l TopPoseByP2DPad_JumpingRight,x
    bra .SplitToX

.JumpingFacingLeft:
    lda.l TopPoseByP2DPad_JumpingLeft,x
    bra .SplitToX

.Ground:
    lda !samus_pose_dir
    and #$0008
    beq .FacingLeft

.FacingRight:
    lda.l TopPoseByP2DPad_Right,x
    bra .SplitToX

.FacingLeft:
    lda.l TopPoseByP2DPad_Left,x
    bra .SplitToX

.GrabbedByDraygonGrappleConnected:
    lda !grapple_x_offset
    php
    lda !grapple_y_offset
    beq .DraygonGrappleY0
    bpl .DraygonGrappleYP

.DraygonGrappleYN:
    plp
    bpl .DraygonGrappleYNXP

.DraygonGrappleYNXN:
    lda #$00BB
    bra .SplitToX

.GrabbedByDraygon:
    lda !grapple_connected
    lsr a
    bcs .GrabbedByDraygonGrappleConnected
    lda !samus_pose_dir
    and #$0008
    beq .GrabbedByDraygonFacingLeft

.GrabbedByDraygonFacingRight:
    lda.l TopPoseByP2DPad_GrabbedByDraygonRight,x
    bra .SplitToX

.DraygonGrappleYNXP:
    lda #$00ED
    bra .SplitToX

.JmpSplitToX:
    bra .SplitToX

.DraygonGrappleY0:
    plp
    bpl .DraygonGrappleY0XP

.DraygonGrappleY0XN:
    lda #$00BC
    bra .SplitToX

.DraygonGrappleY0XP:
    lda #$00EE
    bra .SplitToX

.DraygonGrappleYP:
    plp
    bpl .DraygonGrappleYPXP

.DraygonGrappleYPXN:
    lda #$00BD
    bra .SplitToX

.DraygonGrappleYPXP:
    lda #$00EF
    bra .SplitToX

.GrabbedByDraygonFacingLeft:
    lda.l TopPoseByP2DPad_GrabbedByDraygonLeft,x
    ; bra .SplitToX

.SplitToX:
    jsr .SplitXSub
    clc
    rtl

.SplitToXCrouch:
    jsr .SplitXSub
    sec
    rtl

.SplitXSub:
    pha
    asl a
    rol a
    rol a
    rol a
    rol a
    and #$000F
    tax
    pla
    and #$00FF
    rts

; indexed by samus movement type
; 0 = standing-like
; 1 = jumping-like
; 2 = running-like
; 3 = crouch-like
; 4 = grabbed by draygon
; F = other / undefined behaviour
StatePoseType:
    dw 0    ; 0: Standing
    dw 2    ; 1: Running
    dw 1    ; 2: Normal jumping
    dw $F   ; 3: Spin jumping
    dw $F   ; 4: Morph ball - on ground
    dw 3    ; 5: Crouching
    dw 1    ; 6: Falling
    dw $F   ; 7: Unused. Glitchy morph ball / spin jump
    dw $F   ; 8: Morph ball - falling
    dw $F   ; 9: Unused. Glitchy morph ball
    dw 1    ; $A: Knockback / crystal flash ending
    dw $F   ; $B: Unused. Can fire grapple beam, not moving
    dw $F   ; $C: Unused. Can fire grapple beam and change pose. No pose definitions correspond to this
    dw $F   ; $D: Unused. Can change pose, no firing...
    dw 0    ; $E: Turning around - on ground
    dw 3    ; $F: Crouching/standing/morphing/unmorphing transition
    dw 0    ; $10: Moonwalking
    dw $F   ; $11: Spring ball - on ground
    dw $F   ; $12: Spring ball - in air
    dw $F   ; $13: Spring ball - falling
    dw 1    ; $14: Wall jumping
    dw 0    ; $15: Ran into a wall
    dw 1    ; $16: Grappling
    dw 1    ; $17: Turning around - jumping
    dw 1    ; $18: Turning around - falling
    dw 1    ; $19: Damage boost
    dw 4    ; $1A: Grabbed by Draygon
    dw $F   ; $1B: Shinespark / crystal flash / drained by metroid / damaged by MB's attacks

; low byte indicates top-half pose
; high byte high nibble indicates animation frame
; indexed by d-pad bits (16 entries)
TopPoseByP2DPad_Right:
    dw $0001 ; 0
    dw $000B ; R
    dw $0002 ; L
    dw $000B ; RL
    dw $1017 ; D
    dw $0007 ; DR
    dw $0008 ; DL
    dw $0007 ; DRL
    dw $1003 ; U
    dw $0005 ; UR
    dw $0006 ; UL
    dw $0005 ; URL
    dw $000B ; UD
    dw $000B ; UDR
    dw $0002 ; UDL
    dw $000B ; UDRL

TopPoseByP2DPad_Left:
    dw $000C ; 0
    dw $0001 ; R
    dw $000C ; L
    dw $000C ; RL
    dw $1018 ; D
    dw $0007 ; DR
    dw $0008 ; DL
    dw $0008 ; DRL
    dw $1004 ; U
    dw $0005 ; UR
    dw $0006 ; UL
    dw $0006 ; URL
    dw $000C ; UD
    dw $0001 ; UDR
    dw $000C ; UDL
    dw $000C ; UDRL

TopPoseByP2DPad_JumpingRight:
    dw $0013 ; 0
    dw $0013 ; R
    dw $0014 ; L
    dw $0013 ; RL
    dw $1017 ; D
    dw $006B ; DR
    dw $006C ; DL
    dw $006B ; DRL
    dw $1015 ; U
    dw $0069 ; UR
    dw $006A ; UL
    dw $0069 ; URL
    dw $0013 ; UD
    dw $0013 ; UDR
    dw $0014 ; UDL
    dw $0013 ; UDRL

TopPoseByP2DPad_JumpingLeft:
    dw $0014 ; 0
    dw $0013 ; R
    dw $0014 ; L
    dw $0014 ; RL
    dw $1018 ; D
    dw $006B ; DR
    dw $006C ; DL
    dw $006B ; DRL
    dw $1004 ; U
    dw $0069 ; UR
    dw $006A ; UL
    dw $0069 ; URL
    dw $0014 ; UD
    dw $0013 ; UDR
    dw $0014 ; UDL
    dw $0014 ; UDRL

TopPoseByP2DPad_GrabbedByDraygonRight:
    dw $00EC ; 0
    dw $00EE ; R
    dw $00BC ; L
    dw $00EE ; RL
    dw $00EF ; D -- compromise
    dw $00EF ; DR
    dw $00BD ; DL
    dw $00EE ; DRL
    dw $00ED ; U -- compromise
    dw $00ED ; UR
    dw $00BB ; UL
    dw $00BB ; URL
    dw $00EC ; UD
    dw $00EC ; UDR
    dw $00EC ; UDL
    dw $00EC ; UDRL

TopPoseByP2DPad_GrabbedByDraygonLeft:
    dw $00BA ; 0
    dw $00EE ; R
    dw $00BC ; L
    dw $00BC ; RL
    dw $00BD ; D -- compromise
    dw $00EF ; DR
    dw $00BD ; DL
    dw $00BD ; DRL
    dw $00BB ; U -- compromise
    dw $00ED ; UR
    dw $00BB ; UL
    dw $00BB ; URL
    dw $00BA ; UD
    dw $00BA ; UDR
    dw $00BA ; UDL
    dw $00BA ; UDRL

TopPoseByP2DPad_RunningRight:
    dw $000B ; 0
    dw $000B ; R
    dw $0002 ; L
    dw $000B ; RL
    dw $1017 ; D
    dw $0011 ; DR
    dw $0012 ; DL
    dw $0011 ; DRL
    dw $1003 ; U
    dw $000F ; UR
    dw $0010 ; UL
    dw $000F ; URL
    dw $000B ; UD
    dw $000B ; UDR
    dw $0002 ; UDL
    dw $000B ; UDRL

TopPoseByP2DPad_RunningLeft:
    dw $000C ; 0
    dw $0001 ; R
    dw $000C ; L
    dw $000C ; RL
    dw $1018 ; D
    dw $0011 ; DR
    dw $0012 ; DL
    dw $0012 ; DRL
    dw $1004 ; U
    dw $000F ; UR
    dw $0010 ; UL
    dw 610   ; URL -- FIXME, double check this
    dw $000C ; UD
    dw $0001 ; UDR
    dw $000C ; UDL
    dw $000C ; UDRL

TopPoseByP2DPad_CrouchingRight:
    dw $0027 ; 0
    dw $0027 ; R
    dw $0028 ; L
    dw $0027 ; RL
    dw $1017 ; D
    dw $0073 ; DR
    dw $0074 ; DL
    dw $0073 ; DRL
    dw $1085 ; U
    dw $0071 ; UR
    dw $0072 ; UL
    dw $0071 ; URL
    dw $0027 ; UD
    dw $0027 ; UDR
    dw $0028 ; UDL
    dw $0027 ; UDRL

TopPoseByP2DPad_CrouchingLeft:
    dw $0028 ; 0
    dw $0027 ; R
    dw $0028 ; L
    dw $0028 ; RL
    dw $1018 ; D
    dw $0073 ; DR
    dw $0074 ; DL
    dw $0074 ; DRL
    dw $1086 ; U
    dw $0071 ; UR
    dw $0072 ; UL
    dw $0072 ; URL
    dw $0028 ; UD
    dw $0027 ; UDR
    dw $0028 ; UDL
    dw $0028 ; UDRL

; l-func
; carry set: top half follows P2's aim
ShouldUseCustomPose:
    ; cutscene (also checked in bank90)
    jsl IsInCutscene
    bcs .no

    ; check regular pose can be custom pose
    sep #$20

    lda !samus_pose
    beq .no

    ; binary partition over pose ranges, generated by sucp.py:
    ; yes: $01-$18 $25-$30 $35-$36 $3B-$3C $43-$44 $49-$78 $83-$9A $9C-$A7
    ;      $BF-$C4 $CF-$D2 $E0-$E7 $F1-$FF
    ; yes, regardless of P2's d-pad (grabbed by draygon): $BA-$BE $EC-$F0
.r1_FF:
    cmp #$83
    bcc .r1_82
.r83_FF:
    cmp #$C5
    bcc .r83_C4
.rC5_FF:
    cmp #$E0
    bcc .rC5_DF
.rE0_FF:
    cmp #$EC
    bcc .rE0_EB
.rEC_FF:
    cmp #$F1
    bcc .yes_no_check_buttons
.rF1_FF:
    bra .yes
.rE0_EB:
    cmp #$E8
    bcc .yes
.rE8_EB:
    bra .no
.rC5_DF:
    cmp #$CF
    bcc .no
.rCF_DF:
    cmp #$D3
    bcc .yes
.rD3_DF:
    bra .no
.r83_C4:
    cmp #$A8
    bcc .r83_A7
.rA8_C4:
    cmp #$BA
    bcc .no
.rBA_C4:
    cmp #$BF
    bcc .yes_no_check_buttons
.rBF_C4:
    bra .yes
.r83_A7:
    cmp #$9B
    bcc .yes
.r9B_A7:
    cmp #$9C
    bcc .no
.r9C_A7:
    bra .yes
.r1_82:
    cmp #$3B
    bcc .r1_3A
.r3B_82:
    cmp #$45
    bcc .r3B_44
.r45_82:
    cmp #$49
    bcc .no
.r49_82:
    cmp #$79
    bcc .yes
.r79_82:
    bra .no
.r3B_44:
    cmp #$3D
    bcc .yes
.r3D_44:
    cmp #$43
    bcc .no
.r43_44:
    bra .yes
.r1_3A:
    cmp #$31
    bcc .r1_30
.r31_3A:
    cmp #$35
    bcc .no
.r35_3A:
    cmp #$37
    bcc .yes
.r37_3A:
    bra .no
.r1_30:
    cmp #$19
    bcc .yes
.r19_30:
    cmp #$25
    bcc .no
.r25_30:
    bra .yes

.no:
    rep #$21
    rtl

.yes:
    rep #$20
    lda !joy2_prev
    and #$0F00
    beq .no
    rep #$20
    sec
    rtl

.yes_no_check_buttons:
    rep #$20
    sec
    rtl

; ==============================================================================
%bank($9B)
; ==============================================================================

; grapple
%org($B88C)
    jsr GetTopPose_Safe_NoX_9B
%org($B8D5)
    jsr GetTopPose_Safe_NoX_9B

; P2 decreases/increases grapple length (d-pad)
; (P1 still swings left/right, as the motion person)
%org($BB64)
    lda !joy2_new

%org($BF21)
    jsr GetTopPose_Safe_NoX_9B

; P2 fires grapple
%org($C4F0)
    lda !joy2_new
%org($C51E)
    jsr GetTopPose_Safe_NoX_9B

; P2 controls grapple
%org($C6BC)
    lda !joy2_held
%org($C6E1)
    lda !joy2_held
%org($C703)
    lda !joy2_held
%org($C759)
    lda !joy2_held
%org($C77E)
    lda !joy2_held
%org($C79D)
    lda !joy2_held
%org($C814)
    lda !joy2_held

%org($FDA0)
GetTopPose_Safe_NoX_9B:
    jsl GetTopPose_Safe_NoX
    rts

; ==============================================================================
%bank($B4)
; ==============================================================================

; P2 start no longer enters game state $1D (debug)
%org($9961)
    lda #$0000
    rts
    nop

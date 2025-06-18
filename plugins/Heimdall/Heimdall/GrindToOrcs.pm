package Heimdall::GrindToOrcs;

use strict;
use warnings;
use Globals qw($char $field);
use Log qw(message);
use Heimdall::CombatManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::GrindToOrcs';

# Spore grind function - handles level progression from Payon to Prontera
sub sporeGrind {
    return unless $char;
    return unless $field;
    
    my $current_level = $char->{lv} || 0;
    my $current_map = $field->baseName;
    
    message "[" . $plugin_name . "] Current level: $current_level\n", "info";
    
    # Level 44+ - End game, return to Prontera and stay idle
    if ($current_level >= 44) {
        if ($current_map eq "prontera") {
            message "[" . $plugin_name . "] Level 44+ reached and in Prontera - staying idle\n", "success";
            return 1; # Mission accomplished - stay idle
        } else {
            # Go to Payon Kafra and teleport to Prontera
            teleportToProntera();
            return 0;
        }
    }
    
    # Level 32-43 - Hunt in pay_fild09
    elsif ($current_level >= 32) {
        my $target_map = "pay_fild09";
        if ($current_map ne $target_map) {
            message "[" . $plugin_name . "] Level $current_level - moving to $target_map\n", "info";
            main::ai_route($target_map, undef, undef);
            return 0;
        }
        
        message "[" . $plugin_name . "] Level $current_level - hunting in $target_map until 44\n", "info";
        Heimdall::CombatManager::huntMonsters();
        return 0;
    }
    
    # Level 24-31 - Hunt in pay_fild07
    elsif ($current_level >= 24) {
        my $target_map = "pay_fild07";
        if ($current_map ne $target_map) {
            message "[" . $plugin_name . "] Level $current_level - moving to $target_map\n", "info";
            main::ai_route($target_map, undef, undef);
            return 0;
        }
        
        message "[" . $plugin_name . "] Level $current_level - hunting in $target_map until 32\n", "info";
        Heimdall::CombatManager::huntMonsters();
        return 0;
    }
    
    # Level 1-23 - Hunt in pay_fild08
    else {
        my $target_map = "pay_fild08";
        if ($current_map ne $target_map) {
            message "[" . $plugin_name . "] Level $current_level - moving to $target_map\n", "info";
            main::ai_route($target_map, undef, undef);
            return 0;
        }
        
        message "[" . $plugin_name . "] Level $current_level - hunting in $target_map until 24\n", "info";
        Heimdall::CombatManager::huntMonsters();
        return 0;
    }
}

# Teleport to Prontera via Payon Kafra
sub teleportToProntera {
    return unless $char;
    return unless $field;
    
    my $current_map = $field->baseName;
    my $payon_map = "payon";
    
    # Step 1: Move to Payon if not there
    if ($current_map ne $payon_map) {
        message "[" . $plugin_name . "] Moving to Payon to use Kafra teleport to Prontera\n", "info";
        main::ai_route($payon_map, undef, undef);
        return 0;
    }
    
    # Step 2: Go to Kafra in Payon
    my $kafra_x = 181;  # Kafra coordinates in Payon
    my $kafra_y = 104;
    
    # Check if we're close to Kafra
    my $char_x = $char->{pos_to}{x};
    my $char_y = $char->{pos_to}{y};
    my $distance = abs($char_x - $kafra_x) + abs($char_y - $kafra_y);
    
    if ($distance > 3) {
        message "[" . $plugin_name . "] Moving to Payon Kafra at ($kafra_x, $kafra_y)\n", "info";
        main::ai_route($payon_map, $kafra_x, $kafra_y);
        return 0;
    }
    
    # Step 3: Talk to Kafra for teleport to Prontera
    message "[" . $plugin_name . "] Talking to Kafra for teleport to Prontera\n", "info";
    main::ai_talkNPC($kafra_x, $kafra_y, "r2 r0");  # Service -> Teleport -> Prontera -> Confirm
    
    return 0;
}

1; 
package Heimdall::LevelingManager;

use strict;
use warnings;
use Globals qw($char %config $messageSender);
use Log qw(message);
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::LevelingManager';

# Handle level up event and distribute stat points
sub onLevelUp {
    return unless $char;
    return unless $char->{points_free} && $char->{points_free} > 0;
    
    message "[" . $plugin_name . "] Level up detected! Free points: $char->{points_free}\n", "success";
    
    # Get job class from config (default to "stalker")
    my $job_class = Heimdall::ConfigManager::getConfig('job_class') || 'stalker';
    $job_class = lc($job_class); # Normalize to lowercase
    
    message "[" . $plugin_name . "] Current job class: $job_class\n", "info";
    
    # Distribute stats based on job class
    if ($job_class eq 'stalker') {
        distributeStalkerStats();
    } else {
        message "[" . $plugin_name . "] Unknown job class '$job_class', defaulting to stalker build\n", "warning";
        distributeRogueStats();
    }
}

# Stalker stat distribution logic
sub distributeStalkerStats {
    message "[" . $plugin_name . "] Distributing stats for Stalker build\n", "info";
    
    while ($char->{points_free} > 0) {
        my $agi = $char->{agi_bonus} + $char->{agi};
        my $dex = $char->{dex_bonus} + $char->{dex};
        my $str = $char->{str_bonus} + $char->{str};
        my $luk = $char->{luk_bonus} + $char->{luk};
        my $vit = $char->{vit_bonus} + $char->{vit};
        
        my $success = 0;
        
        # Phase 1: AGI and DEX to 70 (ping-pong between them)
        if ($agi < 70 || $dex < 70) {
            if ($agi < $dex && $agi < 70) {
                # AGI is lower, increase AGI
                $success = addStatPoint('agi');
                message "[" . $plugin_name . "] Phase 1: AGI/DEX to 70 - Increasing AGI (was lower): $agi -> " . ($agi + 1) . "\n", "info" if $success;
            } elsif ($dex < $agi && $dex < 70) {
                # DEX is lower, increase DEX
                $success = addStatPoint('dex');
                message "[" . $plugin_name . "] Phase 1: AGI/DEX to 70 - Increasing DEX (was lower): $dex -> " . ($dex + 1) . "\n", "info" if $success;
            } elsif ($agi == $dex && $agi < 70) {
                # They're equal, alternate (prefer AGI first when tied)
                $success = addStatPoint('agi');
                message "[" . $plugin_name . "] Phase 1: AGI/DEX to 70 - Equal stats, increasing AGI: $agi -> " . ($agi + 1) . "\n", "info" if $success;
            } elsif ($agi < 70) {
                # Only AGI needs more points
                $success = addStatPoint('agi');
                message "[" . $plugin_name . "] Phase 1: AGI/DEX to 70 - Finishing AGI: $agi -> " . ($agi + 1) . "\n", "info" if $success;
            } elsif ($dex < 70) {
                # Only DEX needs more points
                $success = addStatPoint('dex');
                message "[" . $plugin_name . "] Phase 1: AGI/DEX to 70 - Finishing DEX: $dex -> " . ($dex + 1) . "\n", "info" if $success;
            } else {
                # This shouldn't happen, but safety check
                message "[" . $plugin_name . "] Phase 1 logic error - no stat to allocate\n", "error";
                $success = 0;
            }
        }
        # Phase 2: STR and LUK to 30 (ping-pong between them)
        elsif ($str < 30 || $luk < 30) {
            if ($str < $luk && $str < 30) {
                # STR is lower, increase STR
                $success = addStatPoint('str');
                message "[" . $plugin_name . "] Phase 2: STR/LUK to 30 - Increasing STR (was lower): $str -> " . ($str + 1) . "\n", "info" if $success;
            } elsif ($luk < $str && $luk < 30) {
                # LUK is lower, increase LUK
                $success = addStatPoint('luk');
                message "[" . $plugin_name . "] Phase 2: STR/LUK to 30 - Increasing LUK (was lower): $luk -> " . ($luk + 1) . "\n", "info" if $success;
            } elsif ($str == $luk && $str < 30) {
                # They're equal, alternate (prefer STR first when tied)
                $success = addStatPoint('str');
                message "[" . $plugin_name . "] Phase 2: STR/LUK to 30 - Equal stats, increasing STR: $str -> " . ($str + 1) . "\n", "info" if $success;
            } elsif ($str < 30) {
                # Only STR needs more points
                $success = addStatPoint('str');
                message "[" . $plugin_name . "] Phase 2: STR/LUK to 30 - Finishing STR: $str -> " . ($str + 1) . "\n", "info" if $success;
            } elsif ($luk < 30) {
                # Only LUK needs more points
                $success = addStatPoint('luk');
                message "[" . $plugin_name . "] Phase 2: STR/LUK to 30 - Finishing LUK: $luk -> " . ($luk + 1) . "\n", "info" if $success;
            } else {
                # This shouldn't happen, but safety check
                message "[" . $plugin_name . "] Phase 2 logic error - no stat to allocate\n", "error";
                $success = 0;
            }
        }
        # Phase 3: AGI to 99 (same as Rogue)
        elsif ($agi < 99) {
            $success = addStatPoint('agi');
            message "[" . $plugin_name . "] Phase 3: AGI to 99 - AGI: $agi\n", "info" if $success;
        }
        # Phase 4: DEX to 85 (Stalker gets 1 more DEX)
        elsif ($dex < 85) {
            $success = addStatPoint('dex');
            message "[" . $plugin_name . "] Phase 4: DEX to 85 - DEX: $dex\n", "info" if $success;
        }
        # Phase 5: VIT to 19 (Stalker exclusive)
        elsif ($vit < 19) {
            $success = addStatPoint('vit');
            message "[" . $plugin_name . "] Phase 5: VIT to 19 - VIT: $vit\n", "info" if $success;
        }
        # All stats complete for Stalker
        else {
            message "[" . $plugin_name . "] Stalker stat build complete! AGI: $agi, DEX: $dex, STR: $str, LUK: $luk, VIT: $vit\n", "success";
            last;
        }
        
        # Break if we couldn't allocate any points (not enough points for next stat)
        if (!$success) {
            message "[" . $plugin_name . "] Cannot allocate more stat points - insufficient points remaining\n", "warning";
            last;
        }
    }
}

# Add a single stat point to the specified stat
# Returns 1 on success, 0 on failure (not enough points)
sub addStatPoint {
    my $stat = shift;
    return 0 unless $stat;
    return 0 unless $char->{points_free} > 0;
    
    # Map stat names to OpenKore stat IDs
    my %stat_map = (
        'str' => 13,
        'agi' => 14,
        'vit' => 15,
        'int' => 16,
        'dex' => 17,
        'luk' => 18
    );
    
    my $stat_id = $stat_map{lc($stat)};
    if (!defined $stat_id) {
        message "[" . $plugin_name . "] Invalid stat name: $stat\n", "error";
        return 0;
    }
    
    # Calculate the cost to increase this stat
    my $stat_name = lc($stat);
    my $bonus_field = $stat_name . '_bonus';
    my $current_stat = $char->{$bonus_field} + $char->{$stat_name};
    my $cost = getStatCost($current_stat);
    
    # Check if we have enough points
    if ($char->{points_free} < $cost) {
        message "[" . $plugin_name . "] Not enough points to increase $stat (need $cost, have $char->{points_free})\n", "warning";
        return 0;
    }
    
    # Send stat point allocation command
    $messageSender->sendAddStatusPoint($stat_id, 1);
    
    message "[" . $plugin_name . "] Successfully allocated 1 point to $stat (cost: $cost points)\n", "info";
    return 1;
}

# Calculate the cost to increase a stat based on current value
sub getStatCost {
    my $current_stat = shift;
    
    # Ragnarok Online stat cost formula
    if ($current_stat < 10) {
        return 2;
    } elsif ($current_stat < 20) {
        return 3;
    } elsif ($current_stat < 30) {
        return 4;
    } elsif ($current_stat < 40) {
        return 5;
    } elsif ($current_stat < 50) {
        return 6;
    } elsif ($current_stat < 60) {
        return 7;
    } elsif ($current_stat < 70) {
        return 8;
    } elsif ($current_stat < 80) {
        return 9;
    } elsif ($current_stat < 90) {
        return 10;
    } elsif ($current_stat < 100) {
        return 11;
    } else {
        return 12; # Max cost
    }
}

# Get current stat build progress summary
sub getStatSummary {
    return unless $char;
    
    my $agi = $char->{agi_bonus} + $char->{agi};
    my $dex = $char->{dex_bonus} + $char->{dex};
    my $str = $char->{str_bonus} + $char->{str};
    my $luk = $char->{luk_bonus} + $char->{luk};
    my $vit = $char->{vit_bonus} + $char->{vit};
    my $int = $char->{int_bonus} + $char->{int};
    
    return "STR: $str, AGI: $agi, VIT: $vit, INT: $int, DEX: $dex, LUK: $luk (Free: $char->{points_free})";
}

1; 
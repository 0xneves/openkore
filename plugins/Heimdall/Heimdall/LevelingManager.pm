package Heimdall::LevelingManager;

use strict;
use warnings;
use Globals qw($char %config $messageSender);
use Log qw(message);
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::LevelingManager';

# Job progression mapping - defines the complete progression path for each target class
my %job_progression = (
    'stalker' => {
        path => ['novice', 'thief', 'rogue', 'novice_high', 'thief_high', 'stalker'],
        first_job => 'thief',
        second_job => 'rogue',
        transcendent_job => 'stalker'
    },
    'sinx' => {
        path => ['novice', 'thief', 'assassin', 'novice_high', 'thief_high', 'sinx'],
        first_job => 'thief',
        second_job => 'assassin', 
        transcendent_job => 'sinx'
    },
    'lord_knight' => {
        path => ['novice', 'swordsman', 'knight', 'novice_high', 'swordsman_high', 'lord_knight'],
        first_job => 'swordsman',
        second_job => 'knight',
        transcendent_job => 'lord_knight'
    },
    'high_wizard' => {
        path => ['novice', 'mage', 'wizard', 'novice_high', 'mage_high', 'high_wizard'],
        first_job => 'mage',
        second_job => 'wizard',
        transcendent_job => 'high_wizard'
    },
    'sniper' => {
        path => ['novice', 'archer', 'hunter', 'novice_high', 'archer_high', 'sniper'],
        first_job => 'archer',
        second_job => 'hunter',
        transcendent_job => 'sniper'
    },
    'whitesmith' => {
        path => ['novice', 'merchant', 'blacksmith', 'novice_high', 'merchant_high', 'whitesmith'],
        first_job => 'merchant',
        second_job => 'blacksmith',
        transcendent_job => 'whitesmith'
    },
    'high_priest' => {
        path => ['novice', 'acolyte', 'priest', 'novice_high', 'acolyte_high', 'high_priest'],
        first_job => 'acolyte',
        second_job => 'priest',
        transcendent_job => 'high_priest'
    }
);

# Job ID mapping - maps job names to their OpenKore job IDs
my %job_id_map = (
    'novice' => 0,
    'swordsman' => 1,
    'mage' => 2,
    'archer' => 3,
    'acolyte' => 4,
    'merchant' => 5,
    'thief' => 6,
    'knight' => 7,
    'priest' => 8,
    'wizard' => 9,
    'blacksmith' => 10,
    'hunter' => 11,
    'assassin' => 12,
    'rogue' => 17,
    'stalker' => 4018,
    'sinx' => 4015
    # Add more as needed
);

# Reverse job ID mapping - maps job IDs to job names
my %job_name_map = reverse %job_id_map;

# Main loop safety check - handles missed points and skill allocation
sub checkStatsAndSkills {
    return unless $char;
    
    # Check for accumulated stat points (7+ points means we missed some allocations)
    if ($char->{points_free} && $char->{points_free} >= 7) {
        message "[" . $plugin_name . "] Safety check: Found $char->{points_free} unallocated stat points\n", "warning";
        
        # Get job class and distribute stats
        my $job_class = Heimdall::ConfigManager::getConfig('job_class');
        $job_class = lc($job_class); # Normalize to lowercase
        
        if ($job_class eq 'stalker') {
            distributeStalkerStats();
        } else {
            distributeStalkerStats(); # Default to stalker
        }
    }
    
    # Check for skill points (any amount > 0)
    if ($char->{points_skill} && $char->{points_skill} > 0) {
        # Only allocate skill points for Novice class
        if ($char->{jobID} == 0) {
            message "[" . $plugin_name . "] Safety check: Found $char->{points_skill} unallocated skill points (Novice)\n", "info";
            allocateBasicSkill();
        }
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

# Get the next job in progression for a target class
sub getNextJob {
    my $target_class = shift;
    return unless $target_class && $char;
    
    $target_class = lc($target_class);
    return unless exists $job_progression{$target_class};
    
    my $current_job_id = $char->{jobID};
    my $current_job_name = $job_name_map{$current_job_id} || 'unknown';
    
    my $progression = $job_progression{$target_class};
    my @path = @{$progression->{path}};
    
    # Find current position in progression path
    for my $i (0..$#path) {
        if ($path[$i] eq $current_job_name) {
            # Found current job, return next job in path
            if ($i < $#path) {
                return $path[$i + 1];
            } else {
                # Already at final job
                return undef;
            }
        }
    }
    
    # Current job not found in path, return first job
    return $path[1]; # Skip novice, return first job change
}

# Check if current job is part of target class progression
sub isJobInProgression {
    my ($target_class, $job_to_check) = @_;
    return 0 unless $target_class && $job_to_check;
    
    $target_class = lc($target_class);
    $job_to_check = lc($job_to_check);
    
    return 0 unless exists $job_progression{$target_class};
    
    my @path = @{$job_progression{$target_class}->{path}};
    return grep { $_ eq $job_to_check } @path;
}

# Get first job for target class (for novice job change)
sub getFirstJob {
    my $target_class = shift;
    return unless $target_class;
    
    $target_class = lc($target_class);
    return unless exists $job_progression{$target_class};
    
    return $job_progression{$target_class}->{first_job};
}

# Get job change dialogue option (r0-r6) for a job
sub getJobDialogueOption {
    my $job_name = shift;
    return unless $job_name;
    
    $job_name = lc($job_name);
    
    my %dialogue_options = (
        'leave' => 0,
        'swordsman' => 1,
        'mage' => 2,
        'archer' => 3,
        'merchant' => 4,
        'thief' => 5,
        'acolyte' => 6
    );
    
    return $dialogue_options{$job_name};
}

# Allocate skill points to Basic Skill (ID #1) for Novice characters
sub allocateBasicSkill {
    return unless $char;
    return unless $char->{points_skill} && $char->{points_skill} > 0;
    return unless $char->{jobID} == 0; # Only for Novice
    
    my $basic_skill_id = 1; # Basic Skill ID
    my $available_points = $char->{points_skill};
    
    message "[" . $plugin_name . "] Allocating $available_points skill points to Basic Skill (ID: $basic_skill_id)\n", "info";
    
    # Allocate all available skill points to Basic Skill
    for my $i (1..$available_points) {
        $messageSender->sendAddSkillPoint($basic_skill_id);
        message "[" . $plugin_name . "] Allocated skill point $i/$available_points to Basic Skill\n", "debug";
    }
}

1; 
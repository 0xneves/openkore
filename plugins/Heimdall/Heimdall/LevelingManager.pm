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
    
    # Check for accumulated stat points (12+ points means we should allocate)
    if ($char->{points_free} && $char->{points_free} >= 12) {
        # Get job class and distribute stats
        my $job_class = Heimdall::ConfigManager::getConfig('job_class');
        $job_class = lc($job_class); # Normalize to lowercase
        
        if ($job_class eq 'stalker') {
            distributeStatsByBuild('stalker');
        } else {
            distributeStatsByBuild('stalker'); # Default to stalker
        }
    }
    
    # Check for skill points (any amount > 0)
    if ($char->{points_skill} && $char->{points_skill} > 0) {
        # Allocate skill points based on job class
        if ($char->{jobID} == 0) {
            # Novice - allocate to Basic Skill
            message "[" . $plugin_name . "] Found $char->{points_skill} unallocated skill points (Novice)\n", "info";
            allocateBasicSkill();
        } elsif ($char->{jobID} == 6) {
            # Thief - allocate according to build order
            message "[" . $plugin_name . "] Found $char->{points_skill} unallocated skill points (Thief)\n", "info";
            allocateThiefSkills();
        }
    }
}

# Dynamic stat distribution system - configuration driven
my %stat_builds = (
    'stalker' => [
        [70, ['agi', 'dex']],    # Phase 1: AGI and DEX to 70 (balanced)
        [30, ['str', 'luk']],    # Phase 2: STR and LUK to 30 (balanced)
        [99, ['agi']],           # Phase 3: AGI to 99
        [85, ['dex']],           # Phase 4: DEX to 85
        [19, ['vit']],           # Phase 5: VIT to 19
    ],
);

# Generic stat distribution engine
sub distributeStatsByBuild {
    my $build_name = shift || 'stalker';
    
    my $phases = $stat_builds{$build_name};
    unless ($phases) {
        message "[" . $plugin_name . "] Unknown stat build: $build_name\n", "error";
        return;
    }
    
    # Only allocate ONE stat point per call - let main loop handle the rest
    my $current_phase = getCurrentStatPhase($phases);
    
    unless ($current_phase) {
        message "[" . $plugin_name . "] Stat build complete!\n", "success";
        return;
    }
    
    my $success = allocateStatInPhase($current_phase);
    
    unless ($success) {
        message "[" . $plugin_name . "] Cannot allocate stat point - insufficient points remaining\n", "warning";
    }
}

# Find current active phase based on character stats
sub getCurrentStatPhase {
    my $phases = shift;
    
    for my $i (0..$#{$phases}) {
        my ($target, $stats) = @{$phases->[$i]};
        
        # Check if any stat in this phase is incomplete
        for my $stat (@$stats) {
            my $current_value = getCurrentStatValue($stat);
            if ($current_value < $target) {
                return {
                    index => $i + 1,
                    target => $target,
                    stats => $stats,
                    phase_desc => join('/', map { uc($_) } @$stats) . " to $target"
                };
            }
        }
    }
    
    return undef; # All phases complete
}

# Allocate one stat point within a phase (handles both single and multi-stat phases)
sub allocateStatInPhase {
    my $phase = shift;
    my ($target, $stats) = ($phase->{target}, $phase->{stats});
    
    # Single stat phase - straightforward
    if (@$stats == 1) {
        my $stat = $stats->[0];
        my $base_current = getCurrentStatValue($stat);
        
        if ($base_current < $target) {
            my $total_before = getTotalStatValue($stat);
            my $success = addStatPoint($stat);
            
            if ($success) {
                my $total_after = getTotalStatValue($stat);
                message "[" . $plugin_name . "] Phase $phase->{index}: $phase->{phase_desc} - " . uc($stat) . " base: $base_current -> " . ($base_current + 1) . " (total: $total_before -> $total_after)\n", "info";
            }
            return $success;
        }
        return 0;
    }
    
    # Multi-stat phase - ping-pong between stats, prioritizing the lowest base stat
    my @incomplete_stats = grep { getCurrentStatValue($_) < $target } @$stats;
    return 0 unless @incomplete_stats;
    
    # Find the stat with lowest base value
    my $lowest_stat = $incomplete_stats[0];
    my $lowest_base = getCurrentStatValue($lowest_stat);
    
    for my $stat (@incomplete_stats[1..$#incomplete_stats]) {
        my $base_value = getCurrentStatValue($stat);
        if ($base_value < $lowest_base) {
            $lowest_stat = $stat;
            $lowest_base = $base_value;
        }
    }
    
    my $total_before = getTotalStatValue($lowest_stat);
    my $success = addStatPoint($lowest_stat);
    
    if ($success) {
        my $total_after = getTotalStatValue($lowest_stat);
        message "[" . $plugin_name . "] Phase $phase->{index}: $phase->{phase_desc} - " . uc($lowest_stat) . " base: $lowest_base -> " . ($lowest_base + 1) . " (total: $total_before -> $total_after)\n", "info";
    }
    return $success;
}

# Get current BASE stat value (for allocation decisions) - bonuses don't count!
sub getCurrentStatValue {
    my $stat = shift;
    return $char->{$stat} || 0;  # Only base stats matter for point allocation
}

# Get total stat value including bonuses (for display/information)
sub getTotalStatValue {
    my $stat = shift;
    return ($char->{$stat} || 0) + ($char->{"${stat}_bonus"} || 0);
}

# Debug function to show current stat distribution progress
sub showStatDistributionStatus {
    my $build_name = shift || 'stalker';
    
    message "[" . $plugin_name . "] === Stat Distribution Status ($build_name) ===\n", "info";
    message "[" . $plugin_name . "] Free points: " . ($char->{points_free} || 0) . "\n", "info";
    
    my $phases = $stat_builds{$build_name};
    unless ($phases) {
        message "[" . $plugin_name . "] Unknown stat build: $build_name\n", "error";
        return;
    }
    
    # Show all stats with base/bonus/total breakdown
    my @all_stats = qw(str agi vit int dex luk);
    message "[" . $plugin_name . "] Current Stats (Base + Bonus = Total):\n", "info";
    
    for my $stat (@all_stats) {
        my $base = getCurrentStatValue($stat);
        my $bonus = ($char->{"${stat}_bonus"} || 0);
        my $total = getTotalStatValue($stat);
        message "[" . $plugin_name . "]   " . uc($stat) . ": $base + $bonus = $total\n", "info";
    }
    
    # Show phase progress
    my $current_phase = getCurrentStatPhase($phases);
    if ($current_phase) {
        message "[" . $plugin_name . "] Current Phase: $current_phase->{index} ($current_phase->{phase_desc})\n", "info";
        
        # Show progress for each stat in current phase
        for my $stat (@{$current_phase->{stats}}) {
            my $base = getCurrentStatValue($stat);
            my $target = $current_phase->{target};
            my $remaining = $target - $base;
            message "[" . $plugin_name . "]   " . uc($stat) . ": $base/$target (need $remaining more base points)\n", "info";
        }
    } else {
        message "[" . $plugin_name . "] All phases complete!\n", "success";
    }
    
    message "[" . $plugin_name . "] === End Status ===\n", "info";
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
    
    # Calculate the cost to increase this stat (based on total current stat)
    my $current_total_stat = getTotalStatValue($stat);
    my $cost = getStatCost($current_total_stat);
    
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

# Get current stat build progress summary (shows total stats for display)
sub getStatSummary {
    return unless $char;
    
    my $str = getTotalStatValue('str');
    my $agi = getTotalStatValue('agi');
    my $vit = getTotalStatValue('vit');
    my $int = getTotalStatValue('int');
    my $dex = getTotalStatValue('dex');
    my $luk = getTotalStatValue('luk');
    
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
sub getFirstJobDialogueOption {
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
    
    # Allocate only ONE skill point per call - let main loop handle the rest
    $messageSender->sendAddSkillPoint($basic_skill_id);
    message "[" . $plugin_name . "] Allocated 1 skill point to Basic Skill (ID: $basic_skill_id)\n", "info";
}

# Allocate skill points for Thief class following optimal build order
sub allocateThiefSkills {
    return unless $char;
    return unless $char->{points_skill} && $char->{points_skill} > 0;
    return unless $char->{jobID} == 6; # Only for Thief
    
    # Thief skill progression order: 48->10, 49->10, 50->10, 51->5, 52->3, 53->1
    my @skill_progression = (
        {id => 48, name => 'Double Attack', target => 10},
        {id => 49, name => 'Dodge', target => 10},
        {id => 50, name => 'Steal', target => 10},
        {id => 51, name => 'Hiding', target => 5},
        {id => 52, name => 'Envenom', target => 3},
        {id => 53, name => 'Detoxify', target => 1}
    );
    
    # Find the next skill that needs points
    for my $skill (@skill_progression) {
        my $current_level = $char->{skills}{$skill->{id}}{lv} || 0;
        
        if ($current_level < $skill->{target}) {
            # This skill needs more points - allocate one point
            $messageSender->sendAddSkillPoint($skill->{id});
            message "[" . $plugin_name . "] Allocated 1 skill point to $skill->{name} (ID: $skill->{id}) - Level: $current_level -> " . ($current_level + 1) . " / $skill->{target}\n", "info";
            return; # Only allocate ONE skill point per call
        }
    }
    
    # All skills are maxed according to build
    message "[" . $plugin_name . "] Thief skill build complete!\n", "success";
}

1; 
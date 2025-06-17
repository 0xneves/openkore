package Heimdall::CombatManager;

use strict;
use warnings;
use Globals qw($char $monstersList $field @monstersID);
use Log qw(message);
use Utils qw(distance);
use AI;
use Misc qw(positionNearPortal);
use Heimdall::ResourceManager;
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::CombatManager';

# Persistent hunting state (like lockMap functionality)
my $hunting_destination = undef;
my $hunting_mode = 'idle'; # 'idle', 'routing', 'hunting'
my $last_monster_check = 0;

# Check if AI is busy (routing, moving, or attacking)
# Returns 1 if busy, 0 if idle
sub isAIBusy {
    return AI::is("route") || AI::is("move") || AI::is("attack");
}

# Check HP and use potions if needed
sub checkHP {
    return unless $char;
    
    my $hp_percent = ($char->{hp} / $char->{hp_max}) * 100;
    
    if ($hp_percent < Heimdall::ConfigManager::getConfig('hp_threshold')) {
        message "[" . $plugin_name . "] HP is low ($hp_percent%), attempting to use potion\n", "warning";
        Heimdall::ResourceManager::usePotion();
    }
}

# Hunt monsters in the current area - Enhanced with intelligent routing
sub huntMonsters {
    return unless $char;
    return unless $field;
    
    # First priority: Check for nearby monsters to attack
    my $nearby_monster = findNearbyMonster();
    if ($nearby_monster) {
        # Found a monster - enter hunting mode
        if ($hunting_mode eq 'routing') {
            # Cancel current route to attack monster
            AI::clear("route");
            message "[" . $plugin_name . "] Cancelling route to attack nearby monster\n", "info";
        }
        
        $hunting_mode = 'hunting';
        attackMonster($nearby_monster);
        return;
    }
    
    # No nearby monsters - handle routing logic
    if ($hunting_mode eq 'hunting') {
        # Just finished hunting, reset mode
        $hunting_mode = 'idle';
        message "[" . $plugin_name . "] Combat finished, resuming intelligent routing\n", "info";
    }
    
    # Check if we need a new destination or if we reached current one
    if (!$hunting_destination || hasReachedDestination()) {
        # Pick new destination and start routing
        $hunting_destination = getRandomSafeLocation();
        if ($hunting_destination) {
            $hunting_mode = 'routing';
            return if isAIBusy(); # Don't interrupt existing AI
            
            message "[" . $plugin_name . "] New hunting destination: ($hunting_destination->{x}, $hunting_destination->{y})\n", "info";
            main::ai_route($field->baseName, $hunting_destination->{x}, $hunting_destination->{y}, 
                isRandomWalk => 1,
                noMapRoute => 1,
                avoidWalls => 1,
                noSitAuto => 1);
        }
    } elsif ($hunting_mode eq 'routing') {
        # Currently routing - check if we need to resume route
        if (!AI::is("route") && !isAIBusy()) {
            # Route was interrupted or completed, resume
            message "[" . $plugin_name . "] Resuming route to destination: ($hunting_destination->{x}, $hunting_destination->{y})\n", "debug";
            main::ai_route($field->baseName, $hunting_destination->{x}, $hunting_destination->{y}, 
                isRandomWalk => 1,
                noMapRoute => 1,
                avoidWalls => 1,
                noSitAuto => 1);
        }
    }
}

# Find nearby monster within attack range
sub findNearbyMonster {
    return unless $char;
    
    my $attack_range = 15; # Maximum distance to consider for attack
    my $closest_monster = undef;
    my $closest_distance = 999;
    
    for my $i (0..$#monstersID) {
        next unless $monstersID[$i];
        
        my $monster = $monstersList->getByID($monstersID[$i]);
        next unless $monster;
        next if $monster->{dead};
        
        my $distance = distance($char->{pos_to}, $monster->{pos_to});
        if ($distance <= $attack_range && $distance < $closest_distance) {
            $closest_distance = $distance;
            $closest_monster = {
                id => $monstersID[$i],
                index => $i,
                monster => $monster,
                distance => $distance
            };
        }
    }
    
    return $closest_monster;
}

# Attack a specific monster
sub attackMonster {
    my $monster_data = shift;
    return unless $monster_data && $char;
    
    message "[" . $plugin_name . "] Attacking monster: " . $monster_data->{monster}->name . 
            " (index $monster_data->{index}) at distance $monster_data->{distance}\n", "info";
    
    # Attack using the monster ID (same as "a <index>" command)
    main::attack($monster_data->{id});
}

# Get a random safe location (portal-safe and walkable)
sub getRandomSafeLocation {
    return unless $field;
    
    my $max_attempts = 50; # Prevent infinite loops
    my $attempts = 0;
    
    while ($attempts < $max_attempts) {
        my $randX = int(rand($field->width()));
        my $randY = int(rand($field->height()));
        
        # Check if position is walkable
        next unless $field->isWalkable($randX, $randY);
        
        # Check if position is away from portals (using our existing function)
        next if positionNearPortal({x => $randX, y => $randY}, 5);
        
        # Valid location found
        return {
            x => $randX,
            y => $randY
        };
        
        $attempts++;
    }
    
    # Fallback: return character's current position if no safe location found
    message "[" . $plugin_name . "] Warning: Could not find safe location after $max_attempts attempts\n", "warning";
    return {
        x => $char->{pos_to}{x},
        y => $char->{pos_to}{y}
    };
}

# Check if character has reached the current hunting destination
sub hasReachedDestination {
    return 0 unless $hunting_destination && $char;
    
    my $arrival_distance = 3; # Consider "reached" when within 3 blocks
    my $current_distance = distance($char->{pos_to}, $hunting_destination);
    
    if ($current_distance <= $arrival_distance) {
        message "[" . $plugin_name . "] Reached hunting destination ($hunting_destination->{x}, $hunting_destination->{y})\n", "debug";
        return 1;
    }
    
    return 0;
}

# Reset hunting state (useful for map changes or manual resets)
sub resetHuntingState {
    $hunting_destination = undef;
    $hunting_mode = 'idle';
    $last_monster_check = 0;
    message "[" . $plugin_name . "] Hunting state reset\n", "debug";
}

1; 
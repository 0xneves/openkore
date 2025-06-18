package Heimdall::CombatManager;

use strict;
use warnings;
use Globals qw($char $monstersList $field @monstersID $itemsList @itemsID);
use Log qw(message);
use Utils qw(distance);
use AI;
use Misc qw(positionNearPortal getBestTarget);
use Utils::PathFinding;
use Heimdall::ResourceManager;
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::CombatManager';

# Persistent hunting state (like lockMap functionality)
my $hunting_destination = undef;
my $hunting_mode = 'idle'; # 'idle', 'routing', 'hunting'
my $last_monster_check = 0;

# Monster avoidance mapping - maps to avoid specific monsters
# Key: map name, Value: array of monster names/IDs to avoid
my %monster_avoidance_map = (# Add more maps as needed...
    # Example for later maps:
    # 'moc_fild01' => ['Sandman', 'Desert Wolf'],
    # 'gef_fild01' => ['Orc Warrior', 'Orc Lady'],
);

# Level-based monster avoidance (monsters too strong for character level)
my %level_based_avoidance = (
    # Monster ID => minimum safe level to fight
    1018 => 18,  # Creamy - avoid until level 18
    # Add more as needed based on testing
);

# Check if AI is busy (routing, moving, or attacking)
# Returns 1 if busy, 0 if idle
sub isAIBusy {
    return AI::is("route") || AI::is("move") || AI::is("attack");
}

# Check if a monster should be avoided based on map and level restrictions
sub shouldAvoidMonster {
    my $monster = shift;
    return 1 unless $monster && $char && $field;
    
    my $monster_name = $monster->name;
    my $monster_id = $monster->{nameID};
    my $current_map = $field->baseName;
    my $char_level = $char->{lv} || 1;
    
    # Check map-specific avoidance
    if (exists $monster_avoidance_map{$current_map}) {
        my $avoided_monsters = $monster_avoidance_map{$current_map};
        for my $avoided (@$avoided_monsters) {
            if ($monster_name eq $avoided || $monster_id eq $avoided) {
                message "[" . $plugin_name . "] Avoiding $monster_name (ID: $monster_id) - map restriction on $current_map\n", "debug";
                return 1;
            }
        }
    }
    
    # Check level-based avoidance
    if (exists $level_based_avoidance{$monster_id}) {
        my $min_level = $level_based_avoidance{$monster_id};
        if ($char_level < $min_level) {
            message "[" . $plugin_name . "] Avoiding $monster_name (ID: $monster_id) - character level $char_level < required $min_level\n", "debug";
            return 1;
        }
    }
    
    # Monster is safe to attack
    return 0;
}

# Get list of monsters to avoid on current map (for debugging/info)
sub getAvoidedMonstersForMap {
    return unless $field;
    
    my $current_map = $field->baseName;
    my @avoided_monsters = ();
    
    # Add map-specific avoided monsters
    if (exists $monster_avoidance_map{$current_map}) {
        push @avoided_monsters, @{$monster_avoidance_map{$current_map}};
    }
    
    # Add level-based avoided monsters
    if ($char) {
        my $char_level = $char->{lv} || 1;
        for my $monster_id (keys %level_based_avoidance) {
            my $min_level = $level_based_avoidance{$monster_id};
            if ($char_level < $min_level) {
                push @avoided_monsters, "ID:$monster_id (need level $min_level)";
            }
        }
    }
    
    return @avoided_monsters;
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
    
    # Top priority: Check for nearby items to pick up
    my $nearby_item = getNearbyItem();
    if ($nearby_item) {
        # Found item - pick it up
        message "[" . $plugin_name . "] Picking up item: " . ($nearby_item->{name} || 'Unknown') . "\n", "info";
        main::take($nearby_item->{ID});
        return;
    }
    
    # Second priority: Check for nearby monsters to attack
    my $nearby_monster_id = getBestTarget(\@monstersID, 1, 0);
    if ($nearby_monster_id) {
        # Get monster object to check if we should avoid it
        my $monster_obj = $monstersList->getByID($nearby_monster_id);
        if ($monster_obj && shouldAvoidMonster($monster_obj)) {
            # Monster should be avoided - skip attacking
            message "[" . $plugin_name . "] Skipping monster " . $monster_obj->name . " - marked for avoidance\n", "debug";
        } else {
            # Found a monster - enter hunting mode
            if ($hunting_mode eq 'routing') {
                # Cancel current route to attack monster
                AI::clear("route");
                message "[" . $plugin_name . "] Cancelling route to attack nearby monster\n", "info";
            }
            
            $hunting_mode = 'hunting';
            attackMonster($nearby_monster_id);
            return;
        }
    }
    
    # No nearby monsters - handle routing logic
    if ($hunting_mode eq 'hunting') {
        # Just finished hunting - always resume routing to same destination
        if ($hunting_destination) {
            message "[" . $plugin_name . "] Combat finished, resuming route to ($hunting_destination->{x}, $hunting_destination->{y})\n", "info";
            $hunting_mode = 'routing';
        }
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

# Attack a specific monster
sub attackMonster {
    my $monster_id = shift;
    return unless $monster_id && $char;
    
    # Get monster object for logging
    my $monster = $monstersList->getByID($monster_id);
    if ($monster) {
        my $distance = distance($char->{pos_to}, $monster->{pos_to});
        message "[" . $plugin_name . "] Attacking monster: " . $monster->name . 
                " (ID: $monster_id) at distance $distance\n", "info";
    } else {
        message "[" . $plugin_name . "] Attacking monster ID: $monster_id\n", "info";
    }
    
    # Attack using the monster ID (same as "a <index>" command)
    main::attack($monster_id);
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

# Get nearby item to pick up
sub getNearbyItem {
    return unless $char && $itemsList;
    
    my $max_distance = 5; # Maximum distance to consider an item "nearby"
    
    for my $item (@{$itemsList->getItems()}) {
        next unless $item;
        next unless $item->{pos};
        
        # Calculate distance to item
        my $item_distance = distance($char->{pos_to}, $item->{pos});
        
        if ($item_distance <= $max_distance) {
            # Found nearby item
            return $item;
        }
    }
    
    return undef; # No nearby items found
}

# Reset hunting state (useful for map changes or manual resets)
sub resetHuntingState {
    $hunting_destination = undef;
    $hunting_mode = 'idle';
    $last_monster_check = 0;
    message "[" . $plugin_name . "] Hunting state reset\n", "debug";
}

1; 
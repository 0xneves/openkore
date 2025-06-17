package Heimdall::CombatManager;

use strict;
use warnings;
use Globals qw($char $monstersList $field @monstersID);
use Log qw(message);
use Utils qw(distance);
use AI;
use Heimdall::ResourceManager;
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::CombatManager';

# Check HP and use potions if needed
sub checkHP {
    return unless $char;
    
    my $hp_percent = ($char->{hp} / $char->{hp_max}) * 100;
    
    if ($hp_percent < Heimdall::ConfigManager::getConfig('hp_threshold')) {
        message "[" . $plugin_name . "] HP is low ($hp_percent%), attempting to use potion\n", "warning";
        Heimdall::ResourceManager::usePotion();
    }
}

# Hunt monsters in the current area
sub huntMonsters {
    return unless $char;
    return unless $field;
    
    # Check if there are any monsters using OpenKore's monstersID array (like ml command)
    my $monster_count = 0;
    for my $i (0..$#monstersID) {
        next unless $monstersID[$i];
        $monster_count++;
    }
    
    message "[" . $plugin_name . "] Found $monster_count monsters in area\n", "debug";
    
    if ($monster_count > 0) {
        # Find the closest monster using OpenKore's standard approach
        my $closest_index = -1;
        my $closest_distance = 999;
        
        for my $i (0..$#monstersID) {
            next unless $monstersID[$i];
            
            my $monster = $monstersList->getByID($monstersID[$i]);
            next unless $monster;
            next if $monster->{dead};
            
            my $distance = distance($char->{pos_to}, $monster->{pos_to});
            if ($distance < $closest_distance) {
                $closest_distance = $distance;
                $closest_index = $i;
            }
        }
        
        if ($closest_index >= 0) {
            my $monster = $monstersList->getByID($monstersID[$closest_index]);
            message "[" . $plugin_name . "] Attacking monster: " . $monster->name . " (index $closest_index) at distance $closest_distance\n", "info";
            
            # Attack using the monster ID (same as "a <index>" command)
            main::attack($monstersID[$closest_index]);
        }
    } else {
        # No monsters found, move randomly
        message "[" . $plugin_name . "] No monsters found, moving randomly\n", "info";
        moveRandomly();
    }
}

# Move randomly while avoiding portals
sub moveRandomly {
    return unless $char;
    return unless $field;
    
    # Clear AI to ensure we can move
    AI::clear();
    
    # Use OpenKore's built-in random walk pattern with infinite attempts
    my ($randX, $randY);
    
    while (1) {
        $randX = int(rand($field->width()));
        $randY = int(rand($field->height()));
        
        # Check if position is walkable (this includes portal avoidance)
        last if $field->isWalkable($randX, $randY);
    }
    
    message "[" . $plugin_name . "] Moving randomly to ($randX, $randY)\n", "info";
    
    # Use ai_route with portal avoidance flags
    main::ai_route($field->baseName, $randX, $randY, 
        isRandomWalk => 1,
        noMapRoute => 1);
}

1; 
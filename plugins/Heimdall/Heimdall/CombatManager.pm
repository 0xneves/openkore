package Heimdall::CombatManager;

use strict;
use warnings;
use Globals qw($char $monstersList $field);
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
    
    # Get all monsters in the area
    my @monsters = $monstersList->getItems();
    
    message "[" . $plugin_name . "] Found " . scalar(@monsters) . " monsters in area\n", "debug";
    
    if (@monsters) {
        # Find the closest monster
        my $closest_monster;
        my $closest_distance = 999;
        
        for my $monster_ref (@monsters) {
            # Debug what we got
            message "[" . $plugin_name . "] Monster item: " . (defined $monster_ref ? ref($monster_ref) : "undefined") . "\n", "debug";
            
            if (!$monster_ref) {
                message "[" . $plugin_name . "] Monster ref is undefined, skipping\n", "debug";
                next;
            }
            
            if (ref($monster_ref) ne 'ARRAY') {
                message "[" . $plugin_name . "] Monster ref is not ARRAY, it's: " . ref($monster_ref) . ", skipping\n", "debug";
                next;
            }
            
            message "[" . $plugin_name . "] Processing ARRAY monster ref\n", "debug";
            
            # Debug array contents
            message "[" . $plugin_name . "] Array size: " . scalar(@$monster_ref) . "\n", "debug";
            for my $i (0 .. $#$monster_ref) {
                my $item = $monster_ref->[$i];
                message "[" . $plugin_name . "] Array[$i]: " . (defined $item ? ref($item) || "SCALAR" : "undefined") . "\n", "debug";
            }
            
            # Get the actual monster object from the array
            my $monster = $monster_ref->[0];
            if (!$monster) {
                message "[" . $plugin_name . "] Monster object is undefined, skipping\n", "debug";
                next;
            }
            
            message "[" . $plugin_name . "] Monster object type: " . ref($monster) . "\n", "debug";
            
            if (ref($monster) ne 'HASH') {
                message "[" . $plugin_name . "] Monster object is not HASH, it's: " . ref($monster) . ", skipping\n", "debug";
                next;
            }
            
            # Debug monster properties
            message "[" . $plugin_name . "] Monster: " . ($monster->{name} || "unknown") . " dead=" . ($monster->{dead} || "0") . "\n", "debug";
            
            next if $monster->{dead};
            next unless $monster->{pos_to};
            
            my $distance = distance($char->{pos_to}, $monster->{pos_to});
            if ($distance < $closest_distance) {
                $closest_distance = $distance;
                $closest_monster = $monster;
            }
        }
        
        if ($closest_monster) {
            message "[" . $plugin_name . "] Attacking monster: $closest_monster->{name} at distance $closest_distance\n", "info";
            main::attack($closest_monster->{ID});
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
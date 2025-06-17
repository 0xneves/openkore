package Heimdall::CombatManager;

use strict;
use warnings;
use Globals qw($char $field $monstersList);
use Log qw(message);
use AI qw(ai_route);
use Utils qw(distance);
use Heimdall::ResourceManager;
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::CombatManager';

# Monitor HP and use healing potions when needed
sub checkHP {
    return unless $char;
    return unless $char->{hp_max} && $char->{hp_max} > 0;
    
    my $hp_percent = ($char->{hp} / $char->{hp_max}) * 100;
    
    if ($hp_percent < $Heimdall::ConfigManager::hp_threshold) {
        message "[" . $plugin_name . "] HP low: $hp_percent% \n", "warning";
        
        # Try to use configured potion
        my $potion_id = $Heimdall::ConfigManager::potion_id;

        # Check if we need to purchase potions first
        # TODO: Implement purchase script
        if ($Heimdall::ConfigManager::potion_need_purchase) {
            # Check if we now have potions available
            if (Heimdall::ResourceManager::hasItem($potion_id)) {
                # We have potions again! Reset the purchase flag
                $Heimdall::ConfigManager::potion_need_purchase = 0;
                Heimdall::ConfigManager::saveConfig();
            } else {
                message "[" . $plugin_name . "] Character needs to buy potions!\n", "error";
                return 0;
            }
        }
        
        # Try to use potion
        if (Heimdall::ResourceManager::useItemIfExists($potion_id)) {
            return 1;
        } else {
            # No potions available, check if we have Jornada boxes
            if ($Heimdall::ConfigManager::has_jornada > 0) {
                message "[" . $plugin_name . "] No potions found, opening Caixa de Jornada (remaining: $Heimdall::ConfigManager::has_jornada)\n", "warning";
                
                if (Heimdall::ResourceManager::useItemIfExists(23938)) {
                    # Successfully used Jornada box, decrease counter
                    $Heimdall::ConfigManager::has_jornada--;
                    Heimdall::ConfigManager::saveConfig();
                    message "[" . $plugin_name . "] Opened Caixa de Jornada (remaining: $Heimdall::ConfigManager::has_jornada)\n", "success";
                    return 1;
                } else {
                    message "[" . $plugin_name . "] Caixa de Jornada not found in inventory!\n", "error";
                    return 0;
                }
            } else {
                # No Jornada boxes left, need to purchase potions
                message "[" . $plugin_name . "] No Jornada boxes left! Needs to purchase potions\n", "error";
                $Heimdall::ConfigManager::potion_need_purchase = 1;
                Heimdall::ConfigManager::saveConfig();;
                return 0;
            }
        }
    }
    
    return 0; # HP is fine, no action needed
}

# Get current HP percentage
sub getHPPercent {
    return 0 unless $char && $char->{hp_max} && $char->{hp_max} > 0;
    return ($char->{hp} / $char->{hp_max}) * 100;
}

# Monster hunting function - finds and attacks nearby monsters
sub huntMonsters {
    return unless $char;
    return unless $field;
    
    # Get all monsters on screen
    my @monsters = @{$monstersList->getItems};
    
    if (@monsters) {
        # Find closest monster
        my $closest_monster;
        my $closest_distance = 999;
        
        foreach my $monster (@monsters) {
            next if $monster->{dead};
            next if $monster->{ignore};
            
            my $distance = distance($char->{pos_to}, $monster->{pos_to});
            
            if ($distance < $closest_distance) {
                $closest_distance = $distance;
                $closest_monster = $monster;
            }
        }
        
        if ($closest_monster) {
            message "[" . $plugin_name . "] Found monster: $closest_monster->{name} at distance $closest_distance\n", "info";
            # Attack the monster using the main attack function
            main::attack($closest_monster->{ID});
        } else {
            message "[" . $plugin_name . "] No valid monsters found - moving randomly\n", "info";
            moveRandomly();
        }
    } else {
        message "[" . $plugin_name . "] No monsters on screen - moving randomly\n", "info";
        moveRandomly();
    }
}

# Random movement function - uses OpenKore's exact random walk pattern
sub moveRandomly {
    return unless $char;
    return unless $field;
    
    message "[" . $plugin_name . "] Starting random walk to find monsters\n", "info";
    
    # Generate random coordinates using OpenKore's method
    my ($randX, $randY);
    my $i = 500;
    do {
        $randX = int(rand($field->width-1)+1);
        $randY = int(rand($field->height-1)+1);
    } while (--$i && (!$field->isWalkable($randX, $randY) || $randX == 0 || $randY == 0));
    
    if (!$i) {
        message "[" . $plugin_name . "] Could not find walkable coordinates for random walk\n", "warning";
        return;
    }
    
    message "[" . $plugin_name . "] Moving randomly to ($randX, $randY)\n", "info";
    
    # Use OpenKore's exact ai_route pattern
    ai_route(
        $field->baseName,
        $randX,
        $randY,
        maxRouteTime => 30,
        attackOnRoute => 2,
        noMapRoute => 1,  # Avoid portals
        isRandomWalk => 1
    );
}

1; 
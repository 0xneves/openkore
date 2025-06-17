package Heimdall::ResourceManager;

use strict;
use warnings;
use Globals qw($char);
use Log qw(message);
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::ResourceManager';

# Use a potion based on configuration
sub usePotion {
    return unless $char;
    
    my $potion_id = Heimdall::ConfigManager::getConfig('potion_id');
    my $hp_percent = ($char->{hp} / $char->{hp_max}) * 100;
    
    message "[" . $plugin_name . "] Attempting to use potion (ID: $potion_id) - HP: $hp_percent%\n", "info";
    
    # Try to use configured potion
    if (useItemIfExists($potion_id)) {
        message "[" . $plugin_name . "] Successfully used potion\n", "success";
        return 1;
    }
    
    # Check if we have Jornada boxes as backup
    my $has_jornada = Heimdall::ConfigManager::getConfig('has_jornada');
    if ($has_jornada > 0) {
        message "[" . $plugin_name . "] No potions found, trying Caixa de Jornada (remaining: $has_jornada)\n", "warning";
        
        if (useItemIfExists(23938)) { # Caixa de Jornada ID
            # Successfully used Jornada box, decrease counter
            Heimdall::ConfigManager::setConfig('has_jornada', $has_jornada - 1);
            Heimdall::ConfigManager::saveConfig();
            message "[" . $plugin_name . "] Opened Caixa de Jornada\n", "success";
            return 1;
        }
    }
    
    # No healing items available
    message "[" . $plugin_name . "] No healing items available!\n", "error";
    return 0;
}

# Check if character has a specific item
sub hasItem {
    my $item_id = shift;
    return 0 unless $char && $item_id;
    
    for my $item (@{$char->inventory}) {
        next unless $item;
        return 1 if $item->{nameID} == $item_id && $item->{amount} > 0;
    }
    
    return 0;
}

# Get the amount of a specific item in inventory
sub getItemAmount {
    my $item_id = shift;
    return 0 unless $char && $item_id;
    
    for my $item (@{$char->inventory}) {
        next unless $item;
        return $item->{amount} if $item->{nameID} == $item_id;
    }
    
    return 0;
}

# Use an item if it exists in inventory
sub useItemIfExists {
    my $item_id = shift;
    return 0 unless $char && $item_id;
    
    for my $item (@{$char->inventory}) {
        next unless $item;
        if ($item->{nameID} == $item_id && $item->{amount} > 0) {
            message "[" . $plugin_name . "] Using item: $item->{name} (ID: $item_id)\n", "info";
            main::ai_useItem($item->{binID});
            return 1;
        }
    }
    
    return 0;
}

# Get inventory summary
sub getInventorySummary {
    return "No character data" unless $char;
    
    my $total_items = 0;
    my $total_weight = 0;
    
    for my $item (@{$char->inventory}) {
        next unless $item;
        $total_items += $item->{amount};
        $total_weight += $item->{weight} * $item->{amount};
    }
    
    my $weight_percent = ($char->{weight} / $char->{weight_max}) * 100;
    
    return sprintf("Items: %d, Weight: %d/%d (%.1f%%)", 
                   $total_items, $char->{weight}, $char->{weight_max}, $weight_percent);
}

1; 
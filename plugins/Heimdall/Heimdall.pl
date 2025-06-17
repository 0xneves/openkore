# Heimdall Plugin for OpenKore
# Master plugin for full 1-99 automation
# Version 0.1 - Initial Test

package Heimdall;

use strict;
use warnings;

# Import required OpenKore modules
use Plugins;
use Globals qw($char %config $net $messageSender $field);
use Log qw(message);
use Commands;
use Utils qw(timeOut);

# Plugin information
my $plugin_name = 'Heimdall';
my $plugin_version = '0.1';
my $plugin_description = 'Heimdall - The All-Seeing Stalker Automation Plugin';

# Plugin timeout for main loop
our $timeout;

# Register the plugin
Plugins::register($plugin_name, $plugin_description, \&onUnload, \&onReload);

# Add hooks to OpenKore events
my $hooks = Plugins::addHooks(
    ['packet/map_loaded', \&onMapLoaded],       # When map is fully loaded
    ['mainLoop_pre', \&onMainLoop],             # Main loop
);

# Called when map is fully loaded
sub onMapLoaded {
    message "[" . $plugin_name . "] Map fully loaded - ensuring AI is manual!\n", "success";
    Commands::run("ai manual");
    message "[" . $plugin_name . "] Ready for action!\n", "success";
}

# Called when plugin is loaded/reloaded
sub onReload {
    message "[" . $plugin_name . "] Plugin reloading...\n", "success";
}

# Called when plugin is unloaded
sub onUnload {
    message "[" . $plugin_name . "] Plugin unloading...\n", "success";
    Plugins::delHooks($hooks);
}

# Main loop - core automation logic
sub onMainLoop {
    return unless $net && $net->getState() == Network::IN_GAME;
    return unless timeOut($timeout, 10); # Check every 10 seconds
    
    # Core automation logic will go here
    tutorial();
    
    $timeout = time;
}

# Tutorial function - handles initial character setup
sub tutorial {
    return unless $char;
    return unless $field; # Safety check - field must be loaded
    
    my $current_map = $field->baseName;
    return unless $current_map; # Extra safety - map name must exist
    
    message "[" . $plugin_name . "] DEBUG: Current map is '$current_map'\n", "info";
    
    my $tutorial_map = "iz_int";
    
    if ($current_map eq $tutorial_map) {
        message "[" . $plugin_name . "] In tutorial map ($tutorial_map) - checking for Caixa de Jornada...\n", "success";
        useItemIfExists(23937); # Caixa de Jornada
    }
}

# Check if item exists in inventory by ID
sub hasItem {
    my $item_id = shift;
    
    message "[" . $plugin_name . "] DEBUG: Searching for item ID $item_id\n", "info";
    
    unless ($char) {
        message "[" . $plugin_name . "] DEBUG: \$char is not defined!\n", "error";
        return 0;
    }
    
    unless ($char->{inventory}) {
        message "[" . $plugin_name . "] DEBUG: \$char->{inventory} is not defined!\n", "error";
        return 0;
    }
    
    message "[" . $plugin_name . "] DEBUG: Both \$char and inventory exist, proceeding...\n", "success";
    
    for my $item (@{$char->{inventory}->getItems()}) {
        next unless $item;
        message "[" . $plugin_name . "] DEBUG: Found item nameID: $item->{nameID}, name: $item->{name}\n", "info";
        if ($item->{nameID} == $item_id) {
            return $item;
        }
    }
    
    message "[" . $plugin_name . "] DEBUG: Item $item_id not found in inventory\n", "warning";
    return 0;
}

# Use item if it exists in inventory
sub useItemIfExists {
    my $item_id = shift;
    
    my $item = hasItem($item_id);
    if ($item) {
        message "[" . $plugin_name . "] Found $item->{name} (ID: $item_id) - using it!\n", "success";
        $messageSender->sendItemUse($item->{ID}, $char->{ID});
        return 1;
    } else {
        message "[" . $plugin_name . "] Caixa de Jornada (ID: $item_id) not found in inventory\n", "warning";
        return 0;
    }
}

# Initialize plugin
message "[" . $plugin_name . "] Plugin v" . $plugin_version . " loaded successfully!\n", "success";

1; # Return true for successful loading 
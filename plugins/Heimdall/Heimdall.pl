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
use AI qw(ai_route);
use Utils qw(timeOut);

# Import Heimdall modules
use Heimdall::ResourceManager;
use Heimdall::CombatManager;

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
    ['packet/hp_sp_changed', \&onHPChanged],    # When HP/SP changes (damage taken)
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

# Called when HP/SP changes (damage taken, healing, etc.)
sub onHPChanged {
    my $args = shift;
    
    # Immediately check HP when it changes
    Heimdall::CombatManager::checkHP();
}

# Main loop - core automation logic
sub onMainLoop {
    return unless $net && $net->getState() == Network::IN_GAME;
    return unless timeOut($timeout, 10); # Check every 10 seconds
    
    # Core automation logic (no HP checking here anymore)
    tutorial();
    
    $timeout = time;
}

# Tutorial function - handles initial character setup
sub tutorial {
    return unless $char;
    return unless $field; # Safety check - field must be loaded
    
    my $current_map = $field->baseName;
    return unless $current_map; # Extra safety - map name must exist
    
    my $tutorial_map = "iz_int";
    return unless $current_map eq $tutorial_map; # Exit if not in tutorial map
    
    # Use Caixa de Jornada if available
    Heimdall::ResourceManager::useItemIfExists(23937); # Caixa de Jornada
    
    # Get current character position
    my $char_x = $char->{pos_to}{x};
    my $char_y = $char->{pos_to}{y};
    
    # Conditional movement based on X coordinate
    if ($char_x < 28) {
        # If X is less than 28, move to portal at (27, 30)
        message "[" . $plugin_name . "] X=$char_x < 28, moving to portal (27,30)\n", "success";
        ai_route($field->baseName, 27, 30);
    } elsif ($char_x > 28) {
        # If X is greater than 28, move to int_land (56, 15)
        message "[" . $plugin_name . "] X=$char_x > 28, moving to int_land (56,15)\n", "success";
        ai_route("iz_int", 56, 15);
    }
}

# Initialize plugin
message "[" . $plugin_name . "] Plugin v" . $plugin_version . " loaded successfully!\n", "success";

1; # Return true for successful loading 
# Heimdall Plugin for OpenKore
# Master plugin for full 1-99 automation
# Version 0.1 - Initial Test

package Heimdall;

use strict;
use warnings;

# Import required OpenKore modules
use Plugins;
use Globals qw($char %config $net);
use Log qw(message);
use Utils qw(timeOut);

# Import Heimdall modules
use lib $Plugins::current_plugin_folder;
use Heimdall::ResourceManager;
use Heimdall::CombatManager;
use Heimdall::ConfigManager;
use Heimdall::TutorialManager;

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
    # Reset timeout and call main loop immediately
    $timeout = 0;
    onMainLoop();
    message "[" . $plugin_name . "] Main loop executed immediately after reload\n", "success";
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
    
    # Core automation logic
    Heimdall::TutorialManager::tutorialShip();
    Heimdall::TutorialManager::tutorialIsland();

    $timeout = time;
}

# Load configuration on startup
Heimdall::ConfigManager::loadConfig();

# Initialize plugin
message "[" . $plugin_name . "] Plugin v" . $plugin_version . " loaded successfully!\n", "success";

1; # Return true for successful loading 
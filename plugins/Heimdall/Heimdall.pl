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
use Heimdall::LevelingManager;
use Heimdall::QuestManager;

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
    ['base_level', \&onLevelUp],                # When character levels up
    ['quest_delete', \&onQuestDeleted],         # When a quest is completed/deleted
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
    
    # Re-register hooks after reload
    $hooks = Plugins::addHooks(
        ['packet/map_loaded', \&onMapLoaded],       # When map is fully loaded
        ['packet/hp_sp_changed', \&onHPChanged],    # When HP/SP changes (damage taken)
        ['mainLoop_pre', \&onMainLoop],             # Main loop
        ['base_level', \&onLevelUp],                # When character levels up
        ['quest_delete', \&onQuestDeleted],         # When a quest is completed/deleted
    );
    
    # Reset timeout and call main loop immediately
    $timeout = 0;
    onMainLoop();
    message "[" . $plugin_name . "] Plugin reloaded with hooks restored!\n", "success";
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

# Called when character levels up
sub onLevelUp {
    my $args = shift;
    
    message "[" . $plugin_name . "] Level up detected! Distributing stat points...\n", "success";
    
    # Call the LevelingManager to handle stat distribution
    Heimdall::LevelingManager::onLevelUp();
}

# Called when a quest is deleted/completed
sub onQuestDeleted {
    my $args = shift;
    
    # Call the QuestManager to handle quest completion
    Heimdall::QuestManager::onQuestDeleted($args);
}

# Main loop - core automation logic
sub onMainLoop {
    return unless $net && $net->getState() == Network::IN_GAME;
    return unless timeOut($timeout, 1); # Check every 1 seconds
    
    # Core automation logic
    Heimdall::TutorialManager::tutorialShip();
    Heimdall::TutorialManager::tutorialIsland();

    $timeout = time;
}

# Load configuration on startup
Heimdall::ConfigManager::loadConfig();

# Configure NPC error handling
Heimdall::QuestManager::configureNPCErrorHandling();

# Initialize plugin
message "[" . $plugin_name . "] Plugin v" . $plugin_version . " loaded successfully!\n", "success";

1; # Return true for successful loading 
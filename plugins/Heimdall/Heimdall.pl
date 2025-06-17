# Heimdall Plugin for OpenKore
# Master plugin for full 1-99 automation
# Version 0.1 - Initial Test

package Heimdall;

use strict;
use warnings;

# Import required OpenKore modules
use Plugins;
use Globals qw($char %config $net $messageSender $field $npcsList $questList);
use Log qw(message);
use AI qw(ai_route);
use Utils qw(timeOut);

# Import Heimdall modules
use lib $Plugins::current_plugin_folder;
use Heimdall::ResourceManager;
use Heimdall::CombatManager;
use Heimdall::ConfigManager;

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
    
    # Core automation logic (no HP checking here anymore)
    message "[" . $plugin_name . "] Entering tutorialShip\n", "success";
    tutorialShip();
    message "[" . $plugin_name . "] Entering tutorialIsland\n", "success";
    tutorialIsland();

    $timeout = time;
}

# Tutorial Ship function - handles initial character setup on ship
sub tutorialShip {
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
        message "[" . $plugin_name . "] X=$char_x > 28, moving to iz_int (56,15)\n", "success";
        ai_route("iz_int", 56, 15);
    }
}

# Tutorial Island function - handles character setup on training island
sub tutorialIsland {
    return unless $char;
    return unless $field; # Safety check - field must be loaded
    
    my $current_map = $field->baseName;
    return unless $current_map; # Extra safety - map name must exist
    
    my $tutorial_map = "int_land";
    return unless $current_map eq $tutorial_map; # Exit if not in tutorial island map
    
    # Check if character has Blessing buff
    message "[" . $plugin_name . "] === BLESSING STATUS DEBUG ===\n", "warning";
    
    # Debug: Show all active statuses
    if ($char->{statuses}) {
        message "[" . $plugin_name . "] Active statuses: " . join(", ", keys %{$char->{statuses}}) . "\n", "warning";
    } else {
        message "[" . $plugin_name . "] No statuses found on character\n", "warning";
    }
    
    # Test different blessing variations
    my $has_blessing = $char->statusActive('Blessing');
    my $has_blessing_lower = $char->statusActive('blessing');
    my $has_blessing_upper = $char->statusActive('BLESSING');
    
    message "[" . $plugin_name . "] statusActive('Blessing'): " . ($has_blessing ? "TRUE" : "FALSE") . "\n", "warning";
    message "[" . $plugin_name . "] statusActive('blessing'): " . ($has_blessing_lower ? "TRUE" : "FALSE") . "\n", "warning";
    message "[" . $plugin_name . "] statusActive('BLESSING'): " . ($has_blessing_upper ? "TRUE" : "FALSE") . "\n", "warning";
    
    if (!$has_blessing) {
        message "[" . $plugin_name . "] Character does not have Blessing buff\n", "warning";
        captainDialogue();
        return;
    }
    
    message "[" . $plugin_name . "] Character has Blessing buff - ready for training\n", "success";
}

# Captain Dialogue function - talks to Captain NPC for blessing
sub captainDialogue {
    return unless $char;
    return unless $field;
    
    # Captain NPC coordinates
    my $captain_x = 78;
    my $captain_y = 103;
    
    # Get current character position
    my $char_x = $char->{pos_to}{x};
    my $char_y = $char->{pos_to}{y};
    
    # Check if we're close enough to the Captain (within 2 tiles)
    my $distance = abs($char_x - $captain_x) + abs($char_y - $captain_y);
    
    if ($distance > 2) {
        # Move to Captain's location
        message "[" . $plugin_name . "] Moving to Captain at ($captain_x, $captain_y)\n", "info";
        AI::clear("move");
        ai_route($field->baseName, $captain_x, $captain_y);
        return;
    }
    
    # We're close enough - check quest status to determine dialogue type
    message "[" . $plugin_name . "] Near Captain, checking quest status\n", "info";
    
    # Tutorial quest ID: 21008
    my $tutorial_quest_id = 21008;
    my $quest_accepted = 0;
    
    # Check if we have the tutorial quest active
    if ($questList && exists $questList->{$tutorial_quest_id}) {
        my $quest = $questList->{$tutorial_quest_id};
        if ($quest->{active}) {
            $quest_accepted = 1;
            message "[" . $plugin_name . "] Quest $tutorial_quest_id is active - using second dialogue\n", "info";
        }
    }
    
    if ($quest_accepted) {
        # Quest already accepted - second dialogue (4 continues only)
        message "[" . $plugin_name . "] Starting second dialogue with Captain (4 continues)\n", "info";
        main::ai_talkNPC($captain_x, $captain_y, "c c c c");
    } else {
        # First time - accept quest (response 0 + 7 continues)
        message "[" . $plugin_name . "] Starting first dialogue with Captain (accept + 7 continues)\n", "info";
        main::ai_talkNPC($captain_x, $captain_y, "r0 c c c c c c c");
        
        # Set config flag as backup for future reference
        Heimdall::ConfigManager::setConfig('captain_quest_accepted', 1);
    }
}

# Load configuration on startup
Heimdall::ConfigManager::loadConfig();

# Initialize plugin
message "[" . $plugin_name . "] Plugin v" . $plugin_version . " loaded successfully!\n", "success";

1; # Return true for successful loading 
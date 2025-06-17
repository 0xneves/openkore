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
    ['start3', \&onStartup],                    # Called during OpenKore startup
    ['packet_mapChange', \&onMapEnter],         # When map changes (more reliable)
    ['packet/map_loaded', \&onMapLoaded],       # When map is fully loaded
    ['mainLoop_pre', \&onMainLoop],             # Main loop
);

# Called during OpenKore startup
sub onStartup {
    message "[" . $plugin_name . "] Setting AI to manual mode...\n", "success";
    Commands::run("ai manual");
    message "[" . $plugin_name . "] AI set to manual - Heimdall is now in control!\n", "success";
}

# Called when map changes (ensures AI stays manual)
sub onMapEnter {
    message "[" . $plugin_name . "] Map changed - ensuring AI is manual...\n", "success";
    Commands::run("ai manual");
    message "[" . $plugin_name . "] AI confirmed as manual!\n", "success";
}

# Called when map is fully loaded
sub onMapLoaded {
    message "[" . $plugin_name . "] Map fully loaded - ready for action!\n", "success";
    Commands::run("ai manual");
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

# Main loop - sends random letters to chat for testing
sub onMainLoop {
    return unless $net && $net->getState() == Network::IN_GAME;
    return unless timeOut($timeout, 10); # Every 10 seconds
    
    # Array of random letters
    my @letters = ('a', 'b', 'c', 'i', 'e', 'p', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'o', 'q', 'r', 't', 'u', 'v', 'w', 'x', 'y', 'z');
    
    # Pick a random letter
    my $random_letter = $letters[rand @letters];
    
    # Send to public chat
    Commands::run("c $random_letter");
    
    message "[" . $plugin_name . "] Sent random letter: $random_letter\n", "success";
    
    $timeout = time;
}

# Initialize plugin
message "[" . $plugin_name . "] Plugin v" . $plugin_version . " loaded successfully!\n", "success";
message "[" . $plugin_name . "] Will send random letters to chat every 10 seconds when in game.\n", "success";

1; # Return true for successful loading 
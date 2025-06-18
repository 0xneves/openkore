package Heimdall::StateManager;

use strict;
use warnings;
use Globals qw($char $net);
use Log qw(message);
use Commands;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::StateManager';

# Respawn handling
my $is_alive = 1;
my $last_death_time = 0;

# Job change handling
my $chat_is_busy = 0;

# Chat busy handling
sub setChatBusy {
    $chat_is_busy = 1;
}
sub setChatNotBusy {
    $chat_is_busy = 0;
}
sub isChatBusy {
    return $chat_is_busy;
}

# Check if character is alive
sub isAlive {
    return $is_alive;
}

# Main state management - just handle death/respawn, nothing else
sub manageCharacterState {
    return unless $net && $net->getState() == Network::IN_GAME;
    return unless $char;
    
    # Track state changes
    my $currently_dead = $char->{dead} ? 1 : 0;
    
    # Handle death transition
    if (!$is_alive && $currently_dead) {
        # Still dead - try to respawn
        handleRespawn();
    } elsif ($is_alive && $currently_dead) {
        # Just died
        $is_alive = 0;
        $last_death_time = time;
        message "[" . $plugin_name . "] Character died!\n", "warning";
    } elsif (!$is_alive && !$currently_dead) {
        # Just respawned
        $is_alive = 1;
        message "[" . $plugin_name . "] Character respawned!\n", "success";
    }
    # If alive and not dead, do nothing - let existing systems handle everything
}

# Simple respawn handling
sub handleRespawn {
    return unless $char && $char->{dead};
    
    # Try respawn every 3 seconds forever
    if (time - $last_death_time > 3) {
        message "[" . $plugin_name . "] Attempting respawn...\n", "info";
        Commands::run("respawn");
        $last_death_time = time;
    }
}

1; 
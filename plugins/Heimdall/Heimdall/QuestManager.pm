package Heimdall::QuestManager;

use strict;
use warnings;
use Globals qw($char $field);
use Log qw(message);
use AI;
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::QuestManager';

# Handle quest deletion/completion events
sub onQuestDeleted {
    my $args = shift;
    return unless $char;
    return unless $args && $args->{questID};
    
    my $quest_id = $args->{questID};
    my $current_map = $field ? $field->baseName : "unknown";
    
    # Check for specific quest completion (21008) on int_land map
    if ($quest_id == 21008 && $current_map eq 'int_land') {
        message "[" . $plugin_name . "] Tutorial quest 21008 completed on int_land! Setting config flag and moving to teleport NPC\n", "success";
        
        # Set the config flag to indicate island captain quest is completed
        Heimdall::ConfigManager::setConfig('tutorial_island_captain', 1);
        
        teleportToIzlude();
    }
}

# Talk to teleport NPC with simple next commands
sub teleportToIzlude {
    return unless $char;
    
    my $teleport_x = 49;
    my $teleport_y = 57;
    
    message "[" . $plugin_name . "] Talking to teleport NPC to go to Izlude\n", "info";
    
    # Talk to NPC with multiple next commands to handle teleportation
    main::ai_talkNPC($teleport_x, $teleport_y, "n");
}

1; 
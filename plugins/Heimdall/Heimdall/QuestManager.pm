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
    return unless $field;
    
    my $current_map = $field->baseName;
    
    # OpenKore's quest_delete hook doesn't pass arguments (bug in OpenKore)
    # So we check if we're on int_land and assume it's the tutorial quest
    if ($current_map eq 'int_land') {
        message "[" . $plugin_name . "] Quest deleted on int_land! Assuming tutorial quest 21008 completed, setting config flag and moving to teleport NPC\n", "success";
        
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
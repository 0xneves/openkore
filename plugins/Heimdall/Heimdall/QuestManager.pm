package Heimdall::QuestManager;

use strict;
use warnings;
use Globals qw($char $field $messageSender %config);
use Log qw(message);
use AI;
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::QuestManager';

# Configure OpenKore to auto-handle stuck NPC conversations
sub configureNPCErrorHandling {
    # Set npcWrongStepsMethod to 2 (auto-cancel mode)
    # This makes OpenKore automatically try to end stuck NPC conversations
    $config{npcWrongStepsMethod} = 2;
    message "[" . $plugin_name . "] Configured OpenKore to auto-cancel stuck NPC conversations\n", "info";
}

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

# Close any open NPC dialogue using OpenKore's built-in methods
sub closeNPCDialogue {
    return unless $char;
    return unless $messageSender;
    
    # Check if we're in an NPC conversation
    if (AI::is("NPC")) {
        message "[" . $plugin_name . "] Detected stuck NPC dialogue, using OpenKore's auto-cancel method\n", "warning";
        
        # Get the current NPC task
        my $task = AI::args();
        if ($task && $task->isa('Task::TalkNPC')) {
            # Use OpenKore's built-in method to force cancel the conversation
            $task->{trying_to_cancel} = 1;
            message "[" . $plugin_name . "] Set trying_to_cancel flag on NPC task\n", "info";
            return 1;
        } else {
            # Fallback: Clear AI and send cancel
            message "[" . $plugin_name . "] No NPC task found, clearing AI state\n", "info";
            AI::clear("NPC");
            return 1;
        }
    }
    
    return 0;  # Return false if no dialogue was open
}

# Talk to teleport NPC with simple next commands
sub teleportToIzlude {
    return unless $char;
    
    my $teleport_x = 49;
    my $teleport_y = 57;
    
    # First, close any open NPC dialogue
    if (closeNPCDialogue()) {
        message "[" . $plugin_name . "] Closed existing dialogue, will retry teleport NPC in next cycle\n", "info";
        return;  # Wait for next cycle to talk to teleport NPC
    }
    
    message "[" . $plugin_name . "] Talking to teleport NPC to go to Izlude\n", "info";
    
    # Talk to NPC with multiple next commands to handle teleportation
    main::ai_talkNPC($teleport_x, $teleport_y, "n");
}

1; 
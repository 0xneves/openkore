package Heimdall::TutorialManager;

use strict;
use warnings;
use Globals qw($char %config $net $messageSender $field $npcsList $questList);
use Log qw(message);
use AI qw(ai_route);
use Heimdall::ResourceManager;
use Heimdall::ConfigManager;
use Heimdall::QuestManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::TutorialManager';

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
    
    # Check if we've already completed the island captain quest
    my $captain_completed = Heimdall::ConfigManager::getConfigValue('tutorial_island_captain') || 0;
    
    if ($captain_completed) {
        Heimdall::QuestManager::teleportToIzlude();
        return;
    } else {
        # Quest not completed yet, proceed with normal logic
        # Check if character has Blessing buff (EFST_BLESSING)
        if (!$char->statusActive('EFST_BLESSING')) {
            message "[" . $plugin_name . "] Character does not have Blessing buff\n", "warning";
            captainDialogue();
            return;
        }
        
        message "[" . $plugin_name . "] Character has Blessing buff - ready for training\n", "success";
        
        # Check if we have enough items (ID 6008) to complete the quest
        if (Heimdall::ResourceManager::hasItem(6008) && Heimdall::ResourceManager::getItemAmount(6008) >= 3) {
            # We have enough items, talk to the Sailor
            sailorDialogue();
        } else {
            # We need more items, start hunting monsters
            Heimdall::CombatManager::huntMonsters();
        }
    }
}

# Talk to Sailor NPC at coordinates (58, 69) with 3 next hits
sub sailorDialogue {
    return unless $char;
    
    my $sailor_x = 58;
    my $sailor_y = 69;
    
    message "[" . $plugin_name . "] Attempting to talk to Sailor at ($sailor_x, $sailor_y)\n", "info";
    
    # Talk to NPC and send 3 continue responses
    main::ai_talkNPC($sailor_x, $sailor_y, "n n n n");
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
        main::ai_talkNPC($captain_x, $captain_y, "n n n n");
    } else {
        # First time - accept quest (response 0 + 7 continues)
        message "[" . $plugin_name . "] Starting first dialogue with Captain (accept + 7 continues)\n", "info";
        main::ai_talkNPC($captain_x, $captain_y, "n n n n n n n n");
        
        # Set config flag as backup for future reference
        Heimdall::ConfigManager::setConfig('captain_quest_accepted', 1);
    }
}

1; 
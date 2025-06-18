package Heimdall::TutorialManager;

use strict;
use warnings;
use Globals qw($char %config $net $messageSender $field $npcsList $questList);
use Log qw(message);
use AI qw(ai_route);
use Heimdall::ResourceManager;
use Heimdall::ConfigManager;
use Heimdall::QuestManager;
use Heimdall::CombatManager;
use Heimdall::LevelingManager;

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
        return if Heimdall::CombatManager::isAIBusy();
        ai_route($field->baseName, 27, 30);
    } elsif ($char_x > 28) {
        # If X is greater than 28, move to int_land (56, 15)
        return if Heimdall::CombatManager::isAIBusy();
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

    message "[" . $plugin_name . "] Before Config Manager\n", "success";
    # Use Caixa de Jornada if available
    Heimdall::ResourceManager::useItemIfExists(23937); # Caixa de Jornada
    
    # Check if we've already completed the island captain quest
    my $captain_completed = Heimdall::ConfigManager::getConfig('tutorial_island_captain') || 0;
    
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
    return unless $char && $field;
    
    my $sailor_x = 58;
    my $sailor_y = 69;
    
    # First, close any open NPC dialogue
    if (Heimdall::QuestManager::closeNPCDialogue()) {
        message "[" . $plugin_name . "] Closed existing dialogue, will retry Sailor in next cycle\n", "info";
        return;  # Wait for next cycle to talk to Sailor
    }
    
    message "[" . $plugin_name . "] Attempting to talk to Sailor at ($sailor_x, $sailor_y)\n", "info";
    
    # Talk to NPC and send 3 continue responses
    return if Heimdall::CombatManager::isAIBusy();
    main::ai_route($field->baseName, $sailor_x, $sailor_y);
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
        return if Heimdall::CombatManager::isAIBusy();
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
    
    # First, close any open NPC dialogue
    if (Heimdall::QuestManager::closeNPCDialogue()) {
        message "[" . $plugin_name . "] Closed existing dialogue, will retry Captain in next cycle\n", "info";
        return;  # Wait for next cycle to talk to Captain
    }
    
    if ($quest_accepted) {
        # Quest already accepted - second dialogue (4 continues only)
        message "[" . $plugin_name . "] Starting second dialogue with Captain (4 continues)\n", "info";
        main::ai_talkNPC($captain_x, $captain_y, "n n n n");
    } else {
        # First time - accept quest (response 0 + 7 continues)
        message "[" . $plugin_name . "] Starting first dialogue with Captain (accept + 7 continues)\n", "info";
        main::ai_talkNPC($captain_x, $captain_y, "r0 n n n n n n n");
        
        # Set config flag as backup for future reference
        Heimdall::ConfigManager::setConfig('captain_quest_accepted', 1);
    }
}

# Tutorial First Job function - handles getting to job level 10 and skill allocation
sub tutorialFirstJob {
    return unless $char;
    return unless $field; # Safety check - field must be loaded

    # Check if current job is Novice (job ID 0)
    if ($char->{jobID} != 0) {
        return;
    }
    
    # Check if we have skill points to allocate
    if ($char->{points_skill} && $char->{points_skill} > 0) {
        Heimdall::LevelingManager::allocateBasicSkill();
    }
    
    # Check if job level is less than 10
    if ($char->{lv_job} && $char->{lv_job} < 10) {        
        # Check if we're already in the training map
        my $current_map = $field->baseName;
        my $training_map = "prt_fild08";
        
        if ($current_map eq $training_map) {
            # We're in the training map, start hunting
            Heimdall::CombatManager::huntMonsters();
        } else {
            # Move to training map
            return if Heimdall::CombatManager::isAIBusy();
            main::ai_route($training_map, undef, undef);
        }
    } else if(!Heimdall::StateManager::isChatBusy()) {
        # Close any existing NPC dialogue first
        Heimdall::QuestManager::closeNPCDialogue();
        changeToFirstJob();
    }
}



# Dynamic job change via Valquiria NPC in Izlude
sub changeToFirstJob {
    return unless $char;
    return unless $field;
    
    # Get target class from config
    my $target_class = Heimdall::ConfigManager::getConfig('job_class');
    message "[" . $plugin_name . "] Job change in progress... PATH = " . uc($target_class) . "\n", "success";
    
    # Get the next job in progression
    my $next_job = Heimdall::LevelingManager::getFirstJob($target_class);
    
    if (!$next_job) {
        message "[" . $plugin_name . "] No next job found for target class: $target_class\n", "error";
        return;
    }
    
    # Get dialogue option for the job
    my $job_option = Heimdall::LevelingManager::getFirstJobDialogueOption($next_job);
    
    if (!defined $job_option) {
        message "[" . $plugin_name . "] No dialogue option found for job: $next_job\n", "error";
        return;
    }

    # Valquiria NPC coordinates in Izlude
    my $npc_x = 122;
    my $npc_y = 149;
    my $izlude_map = "izlude";
    
    # Check if we're in Izlude
    my $current_map = $field->baseName;
    
    if ($current_map ne $izlude_map) {
        main::ai_route($izlude_map, undef, undef);
        return;
    }
    
    # We're in Izlude, check if we're close to the NPC
    my $char_x = $char->{pos_to}{x};
    my $char_y = $char->{pos_to}{y};
    my $distance = abs($char_x - $npc_x) + abs($char_y - $npc_y);
    
    if ($distance > 2) {
        main::ai_route($izlude_map, $npc_x, $npc_y);
        return;
    }
    
    # Dynamic job change dialogue sequence: c r1 c r0 c c r{job_option} c
    # Job options for reference:
    # r0 = leave
    # r1 = swordsman  
    # r2 = mage
    # r3 = archer
    # r4 = merchant
    # r5 = thief
    # r6 = acolyte
    if (!Heimdall::CombatManager::isAIBusy() && !Heimdall::StateManager::isChatBusy()) {
        Heimdall::StateManager::setChatBusy();
        my $dialogue_sequence = "c r1 c r0 c c r$job_option c";
        main::ai_talkNPC($npc_x, $npc_y, $dialogue_sequence);
        Heimdall::StateManager::setChatNotBusy();
        message "[" . $plugin_name . "] Job change dialogue sent - changing to $next_job class\n", "success";
    }
}

1; 
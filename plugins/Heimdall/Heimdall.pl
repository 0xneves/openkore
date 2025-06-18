# Heimdall Plugin for OpenKore
# Master plugin for full 1-99 automation
# Version 0.1 - Initial Test

package Heimdall;

use strict;
use warnings;

# Import required OpenKore modules
use Plugins;
use Globals qw($char %config $net $field);
use Log qw(message);
use Utils qw(timeOut);
use Commands;

# Import Heimdall modules
use lib $Plugins::current_plugin_folder;
use Heimdall::StateManager;
use Heimdall::ResourceManager;
use Heimdall::CombatManager;
use Heimdall::ConfigManager;
use Heimdall::TutorialManager;
use Heimdall::LevelingManager;
use Heimdall::QuestManager;
use Heimdall::GatherFirstZeny;

# Plugin information
my $plugin_name = 'Heimdall';
my $plugin_version = '0.1';
my $plugin_description = 'Heimdall - The All-Seeing Stalker Automation Plugin';

# Plugin timeout for main loop
our $timeout;

# Register the plugin
Plugins::register($plugin_name, $plugin_description, \&onUnload, \&onReload);

# Register plugin commands
my $commands = Commands::register(
    ['hei', 'Heimdall plugin commands', \&onCommand]
);

# Add hooks to OpenKore events
my $hooks = Plugins::addHooks(
    ['packet/map_loaded', \&onMapLoaded],       # When map is fully loaded
    ['packet/hp_sp_changed', \&onHPChanged],    # When HP/SP changes (damage taken)
    ['mainLoop_pre', \&onMainLoop],             # Main loop
    ['quest_delete', \&onQuestDeleted],         # When a quest is completed/deleted
    ['npc_talk_done', \&onNpcTalkDone],         # When NPC dialogue ends
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
        ['quest_delete', \&onQuestDeleted],         # When a quest is completed/deleted
        ['npc_talk_done', \&onNpcTalkDone],         # When NPC dialogue ends
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
    Commands::unregister($commands);
}

# Command handler for Heimdall plugin commands
sub onCommand {
    my ($cmd, $args) = @_;
    
    my @params = split(/\s+/, $args);
    my $subcmd = shift @params || '';
    
    if ($subcmd eq 'stats' || $subcmd eq 'summary') {
        # Show current stat distribution summary
        my $summary = Heimdall::LevelingManager::getStatSummary();
        if ($summary) {
            message "[" . $plugin_name . "] $summary\n", "info";
        } else {
            message "[" . $plugin_name . "] Unable to get stat summary (not logged in?)\n", "warning";
        }
        
    } elsif ($subcmd eq 'status') {
        # Show detailed stat distribution status
        my $build = Heimdall::ConfigManager::getConfig('job_class');
        return unless $build;
        Heimdall::LevelingManager::showStatDistributionStatus($build);
        
    } elsif ($subcmd eq 'distribute') {
        # Manually trigger stat distribution
        my $build = Heimdall::ConfigManager::getConfig('job_class');
        return unless $build;
        message "[" . $plugin_name . "] Manually triggering stat distribution for $build build...\n", "info";
        Heimdall::LevelingManager::distributeStatsByBuild($build);
        
    } elsif ($subcmd eq 'hunt') {
        # Manually trigger monster hunting
        message "[" . $plugin_name . "] Manually triggering monster hunting...\n", "info";
        Heimdall::CombatManager::huntMonsters();
        
    } elsif ($subcmd eq 'ai') {
        # Show AI busy status
        my $is_busy = Heimdall::CombatManager::isAIBusy();
        my $status = $is_busy ? "busy" : "idle";
        message "[" . $plugin_name . "] AI Status: $status\n", "info";
        
    } elsif ($subcmd eq 'inventory' || $subcmd eq 'inv') {
        # Show inventory summary
        my $summary = Heimdall::ResourceManager::getInventorySummary();
        if ($summary) {
            message "[" . $plugin_name . "] $summary\n", "info";
        } else {
            message "[" . $plugin_name . "] Unable to get inventory summary (not logged in?)\n", "warning";
        }
        
    } elsif ($subcmd eq 'avoid' || $subcmd eq 'avoidance') {
        # Show monster avoidance status for current map
        unless ($field) {
            message "[" . $plugin_name . "] Not on any map - cannot check avoidance list\n", "warning";
            return;
        }
        
        my $current_map = $field->baseName;
        my @avoided = Heimdall::CombatManager::getAvoidedMonstersForMap();
        
        message "[" . $plugin_name . "] === Monster Avoidance Status ($current_map) ===\n", "info";
        message "[" . $plugin_name . "] Character Level: " . ($char->{lv} || 'Unknown') . "\n", "info";
        
        if (@avoided) {
            message "[" . $plugin_name . "] Avoided Monsters:\n", "info";
            for my $monster (@avoided) {
                message "[" . $plugin_name . "]   - $monster\n", "info";
            }
        } else {
            message "[" . $plugin_name . "] No monsters are being avoided on this map\n", "info";
        }
        message "[" . $plugin_name . "] === End Avoidance Status ===\n", "info";
        
    } elsif ($subcmd eq 'help' || $subcmd eq '') {
        # Show available commands
        message "[" . $plugin_name . "] Available commands:\n", "info";
        message "[" . $plugin_name . "]   hei stats/summary        - Show current stat summary\n", "info";
        message "[" . $plugin_name . "]   hei status               - Show detailed stat distribution status\n", "info";
        message "[" . $plugin_name . "]   hei distribute           - Manually trigger stat distribution\n", "info";
        message "[" . $plugin_name . "]   hei hunt                 - Manually trigger monster hunting\n", "info";
        message "[" . $plugin_name . "]   hei ai                   - Show AI status (busy/idle)\n", "info";
        message "[" . $plugin_name . "]   hei inventory/inv        - Show inventory summary\n", "info";
        message "[" . $plugin_name . "]   hei avoid/avoidance      - Show monster avoidance status\n", "info";
        message "[" . $plugin_name . "]   hei help                 - Show this help\n", "info";
        
    } else {
        message "[" . $plugin_name . "] Unknown command: $subcmd. Use 'hei help' for available commands.\n", "warning";
    }
}

# Called when HP/SP changes (damage taken, healing, etc.)
sub onHPChanged {
    my $args = shift;
    
    # Immediately check HP when it changes
    Heimdall::CombatManager::checkHP();
}

# Called when a quest is deleted/completed
sub onQuestDeleted {
    my $args = shift;
    
    # Call the QuestManager to handle quest completion
    Heimdall::QuestManager::onQuestDeleted($args);
}

# Called when NPC dialogue ends
sub onNpcTalkDone {
    my $args = shift;
    
    # Check if we were waiting for dialogue completion
    if (Heimdall::StateManager::isChatBusy()) {
        Heimdall::StateManager::setChatNotBusy();
        message "[" . $plugin_name . "] NPC dialogue completed - chat no longer busy\n", "success";
    }
}

# Main loop - core automation logic
sub onMainLoop {
    return unless $net && $net->getState() == Network::IN_GAME;
    return unless timeOut($timeout, 5); # Check every 5 seconds
    
    # Manage character state (death/respawn)
    Heimdall::StateManager::manageCharacterState();
    
    # Safety checks for stats and skills
    Heimdall::LevelingManager::checkStatsAndSkills();

    # Core automation logic - tutorials only for low level characters
    if ($char && $char->{lv} && $char->{lv} < 15) {
        Heimdall::TutorialManager::tutorialShip();
        Heimdall::TutorialManager::tutorialIsland();
        Heimdall::TutorialManager::tutorialFirstJob();
    }

    # Core automation logic - get a few zeny before going to payon
    if ($char && $char->{lv} && $char->{lv} < 40 && $char->{jobID} != 0) {
        my $journey_complete = Heimdall::GatherFirstZeny::startJourney();
        if ($journey_complete) {
            # Have enough zeny - go to Payon via Kafra
            Heimdall::GatherFirstZeny::goToPayon();
        }
    }

    $timeout = time;
}

# Load configuration on startup
Heimdall::ConfigManager::loadConfig();

# Configure NPC error handling
Heimdall::QuestManager::configureNPCErrorHandling();

# Initialize plugin
message "[" . $plugin_name . "] Plugin v" . $plugin_version . " loaded successfully!\n", "success";

1; # Return true for successful loading 
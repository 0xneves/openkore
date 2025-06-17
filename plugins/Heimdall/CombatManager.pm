package Heimdall::CombatManager;

use strict;
use warnings;
use Globals qw($char);
use Log qw(message);
use Heimdall::ResourceManager;
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::CombatManager';

# Monitor HP and use healing potions when needed
sub checkHP {
    return unless $char;
    return unless $char->{hp_max} && $char->{hp_max} > 0;
    
    my $hp_percent = ($char->{hp} / $char->{hp_max}) * 100;
    
    if ($hp_percent < $Heimdall::ConfigManager::hp_threshold) {
        message "[" . $plugin_name . "] HP low: ${hp_percent}% (${char->{hp}}/${char->{hp_max}})\n", "warning";
        
        # Try to use configured potion
        my $potion_id = $Heimdall::ConfigManager::potion_id;

        # Check if we need to purchase potions first
        # TODO: Implement purchase script
        if ($Heimdall::ConfigManager::potion_need_purchase) {
            # Check if we now have potions available
            if (Heimdall::ResourceManager::hasItem($potion_id)) {
                # We have potions again! Reset the purchase flag
                $Heimdall::ConfigManager::potion_need_purchase = 0;
                Heimdall::ConfigManager::saveConfig();
            } else {
                message "[" . $plugin_name . "] Character needs to buy potions!\n", "error";
                return 0;
            }
        }
        
        # Try to use potion
        if (Heimdall::ResourceManager::useItemIfExists($potion_id)) {
            return 1;
        } else {
            # No potions available, check if we have Jornada boxes
            if ($Heimdall::ConfigManager::has_jornada > 0) {
                message "[" . $plugin_name . "] No potions found, opening Caixa de Jornada (remaining: $Heimdall::ConfigManager::has_jornada)\n", "warning";
                
                if (Heimdall::ResourceManager::useItemIfExists(23938)) {
                    # Successfully used Jornada box, decrease counter
                    $Heimdall::ConfigManager::has_jornada--;
                    Heimdall::ConfigManager::saveConfig();
                    message "[" . $plugin_name . "] Opened Caixa de Jornada (remaining: $Heimdall::ConfigManager::has_jornada)\n", "success";
                    return 1;
                } else {
                    message "[" . $plugin_name . "] Caixa de Jornada not found in inventory!\n", "error";
                    return 0;
                }
            } else {
                # No Jornada boxes left, need to purchase potions
                message "[" . $plugin_name . "] No Jornada boxes left! Needs to purchase potions\n", "error";
                $Heimdall::ConfigManager::potion_need_purchase = 1;
                Heimdall::ConfigManager::saveConfig();;
                return 0;
            }
        }
    }
    
    return 0; # HP is fine, no action needed
}

# Get current HP percentage
sub getHPPercent {
    return 0 unless $char && $char->{hp_max} && $char->{hp_max} > 0;
    return ($char->{hp} / $char->{hp_max}) * 100;
}

1; 
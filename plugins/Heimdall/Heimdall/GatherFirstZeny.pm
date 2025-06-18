package Heimdall::GatherFirstZeny;

use strict;
use warnings;
use Globals qw($char $field $ai_v);
use Log qw(message);
use Misc qw(completeNpcSell cancelNpcBuySell);
use Heimdall::CombatManager;
use Heimdall::ConfigManager;

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::GatherFirstZeny';

# Track initial weight when starting journey
our $initial_weight;

# Start journey function - get the first 120 zeny to go to Payon
sub startJourney {
    return unless $char;
    
    # Get current zeny amount
    my $current_zeny = $char->{zeny} || 0;
    my $target_zeny = 120; # Minimum zeny needed for Payon trip
    
    if ($current_zeny >= $target_zeny) {
        return 1; # Mission accomplished
    }
    
    # Initialize weight tracking if not set
    if (!defined $initial_weight) {
        $initial_weight = $char->{weight} || 0;
        message "[" . $plugin_name . "] Starting weight tracking: $initial_weight\n", "info";
    }
    
    # Check current weight increase
    my $current_weight = $char->{weight} || 0;
    my $weight_gained = $current_weight - $initial_weight;
    
    # If we've gained 100+ weight, sell items
    if ($weight_gained >= 100) {
        message "[" . $plugin_name . "] Gained $weight_gained weight - time to sell items\n", "warning";
        sellSpecificItemsToNPC();
        return 0;
    }
    
    # Check if we're in prt_fild08 for hunting
    my $current_map = $field->baseName;
    my $hunting_map = "prt_fild08";
    
    if ($current_map ne $hunting_map) {
        message "[" . $plugin_name . "] Moving to hunting map: $hunting_map $char->{pos_to}{x} $char->{pos_to}{y}\n", "info";
        main::ai_route($hunting_map, undef, undef);
        return 0;
    }
    
    # We're in the hunting map - hunt monsters for drops
    Heimdall::CombatManager::huntMonsters();
    
    return 0; # Still working on it
}

# Sell specific item drops to NPC for zeny
sub sellSpecificItemsToNPC {
    return unless $char;
    return unless $field;
    
    # List of item nameIDs we want to sell for zeny
    my @sellable_items = (705, 512, 515, 949, 507, 1102, 622, 909, 713, 938, 1202, 619, 915, 935, 1002, 1010);
    my %sellable_lookup = map { $_ => 1 } @sellable_items;
    
    # First check if we have any of these items to sell
    my $has_items_to_sell = 0;
    for my $item (@{$char->inventory}) {
        next if ($item->{equipped});
        next if (!$sellable_lookup{$item->{nameID}});
        $has_items_to_sell = 1;
        last;
    }
    
    if (!$has_items_to_sell) {
        message "[" . $plugin_name . "] No sellable items found in inventory\n", "warning";
        return 0;
    }
    
    # Simple approach: find any item dealer NPC nearby and talk to them
    my $dealer_x = 57;  # Consumable Dealer coordinates in Izlude
    my $dealer_y = 110;
    my $target_map = "izlude_in";
    
    my $current_map = $field->baseName;
    
    # Move to Prontera if not there
    if ($current_map ne $target_map) {
        message "[" . $plugin_name . "] Moving to $target_map to sell items\n", "info";
        main::ai_route($target_map, undef, undef);
        return 0;
    }
    
    # Check if we're close to the dealer
    my $char_x = $char->{pos_to}{x};
    my $char_y = $char->{pos_to}{y};
    my $distance = abs($char_x - $dealer_x) + abs($char_y - $dealer_y);
    
    if ($distance > 3) {
        message "[" . $plugin_name . "] Moving to Tool Dealer at ($dealer_x, $dealer_y)\n", "info";
        main::ai_route($target_map, $dealer_x, $dealer_y);
        return 0;
    }
    
    # We're close to dealer - check if already in sell dialog
    if (defined $ai_v{'npc_talk'} && $ai_v{'npc_talk'}{'talk'} eq 'sell') {
        # We're in sell dialog - build sell list
        my @sellItems;
        for my $item (@{$char->inventory}) {
            next if ($item->{equipped});           # Skip equipped items
            next if (!$item->{sellable});          # Skip items NPC won't buy
            next if (!$sellable_lookup{$item->{nameID}}); # Skip items not in our list
            
            my %sellItem;
            $sellItem{ID} = $item->{ID};           # Inventory slot ID
            $sellItem{amount} = $item->{amount};   # Sell all of this item
            push @sellItems, \%sellItem;
            
            message "[" . $plugin_name . "] Adding to sell: $item->{name} (ID: $item->{nameID}) x$item->{amount}\n", "info";
        }
        
        # Complete the sale
        if (@sellItems) {
            completeNpcSell(\@sellItems);
            message "[" . $plugin_name . "] Selling " . scalar(@sellItems) . " different item types\n", "success";
            # Reset weight tracking after selling
            $initial_weight = $char->{weight} || 0;
            message "[" . $plugin_name . "] Moving to Payon...\n", "info";
        } else {
            message "[" . $plugin_name . "] No items from list are sellable to this NPC\n", "warning";
            cancelNpcBuySell();
        }
        
        return 1;
    }
    
    # # Not in dialog yet - talk to NPC to sell
    # message "[" . $plugin_name . "] Talking to Tool Dealer to sell items\n", "info";
    # main::ai_talkNPC($dealer_x, $dealer_y, "s");  # "s" = select sell option
    
    return 0;
}

# Go to Payon via Izlude Kafra and save spawn point
sub goToPayon {
    return unless $char;
    return unless $field;
    
    my $current_map = $field->baseName;
    my $izlude_map = "izlude";
    
    # Step 1: Move to Izlude if not there
    if ($current_map ne $izlude_map) {
        message "[" . $plugin_name . "] Moving to Izlude to use Kafra teleport\n", "info";
        main::ai_route($izlude_map, undef, undef);
        return 0;
    }
    
    # Step 2: Go to Kafra in Izlude
    my $kafra_x = 128;  # Kafra coordinates in Izlude
    my $kafra_y = 148;
    
    # Check if we're close to Kafra
    my $char_x = $char->{pos_to}{x};
    my $char_y = $char->{pos_to}{y};
    my $distance = abs($char_x - $kafra_x) + abs($char_y - $kafra_y);
    
    if ($distance > 3) {
        message "[" . $plugin_name . "] Moving to Kafra at ($kafra_x, $kafra_y)\n", "info";
        main::ai_route($izlude_map, $kafra_x, $kafra_y);
        return 0;
    }
    
    # Step 3: Check if we're in Payon already
    if ($current_map eq "payon") {
        # We're in Payon - check if save point is already set to payon
        my $current_save_point = Heimdall::ConfigManager::getConfig('kafra_save_point');
        
        if ($current_save_point ne 'payon') {
            # Haven't saved in Payon yet - save spawn point
            message "[" . $plugin_name . "] In Payon but haven't saved spawn point - saving now\n", "info";
            main::ai_talkNPC(177, 111, "r0 c");  # Talk to Kafra and save spawn point
            Heimdall::ConfigManager::setConfig('kafra_save_point', 'payon');
            Heimdall::ConfigManager::saveConfig();
            message "[" . $plugin_name . "] Spawn point saved in Payon\n", "success";
        }
        return 1; # Mission accomplished
    }
    
    # Step 4: Talk to Kafra for teleport service
    if (defined $ai_v{'npc_talk'} && $ai_v{'npc_talk'}{'talk'} eq 'select') {
        # In Kafra menu - select teleport service
        message "[" . $plugin_name . "] Selecting teleport service\n", "info";
        # Kafra dialogue: teleport service -> Payon
        main::ai_talkNPC($kafra_x, $kafra_y, "r2 r1");  # Talk to Kafra and save spawn point
        return 0;
    }
    
    return 0;
}

1; 
package Heimdall::ResourceManager;

use strict;
use warnings;
use Globals qw($char $messageSender);
use Log qw(message);

# Plugin name for consistent logging
my $plugin_name = 'Heimdall::ResourceManager';

# Check if item exists in inventory by ID
sub hasItem {
    my $item_id = shift;
    return 0 unless $char && $char->inventory;
    
    for my $item (@{$char->inventory->getItems()}) {
        next unless $item;
        if ($item->{nameID} == $item_id) {
            return $item;
        }
    }
    
    return 0;
}

# Use item if it exists in inventory
sub useItemIfExists {
    my $item_id = shift;
    
    my $item = hasItem($item_id);
    if ($item) {
        message "[" . $plugin_name . "] Using $item->{name} (ID: $item_id)\n", "success";
        $messageSender->sendItemUse($item->{ID}, $char->{ID});
        return 1;
    } else {
        return 0;
    }
}

1; 
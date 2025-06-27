package Heimdall::ConfigManager;

use strict;
use warnings;

# Configuration variables
our $hp_threshold = 70;
our $potion_id = 11567;
our $has_jornada = 10;
our $potion_need_purchase = 0;
our $job_class = 'rogue';

# Load configuration from file
sub loadConfig {
    my $config_file = 'control/heimdall.txt';
    
    if (open my $fh, '<', $config_file) {
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^#/ || $line =~ /^\s*$/;  # Skip comments and empty lines
            
            if ($line =~ /^hp_threshold\s+(\d+)$/) {
                $hp_threshold = $1;
            } elsif ($line =~ /^potion_id\s+(\d+)$/) {
                $potion_id = $1;
            } elsif ($line =~ /^has_jornada\s+(\d+)$/) {
                $has_jornada = $1;
            } elsif ($line =~ /^potion_need_purchase\s+(\d+)$/) {
                $potion_need_purchase = $1;
            } elsif ($line =~ /^job_class\s+(\w+)$/) {
                $job_class = $1;
            }
        }
        close $fh;
        print "[Heimdall::ConfigManager] Loaded config file\n";
    } else {
        print "[Heimdall::ConfigManager] Could not load config file\n";
    }
}

# Save configuration to file
sub saveConfig {
    my $config_file = 'control/heimdall.txt';
    
    if (open my $fh, '>', $config_file) {
        print $fh "# Heimdall Plugin Configuration\n\n";
        print $fh "# HP percentage threshold to trigger hp potion usage (0-100)\n";
        print $fh "hp_threshold $hp_threshold\n\n";
        print $fh "# Potion ID to use\n";
        print $fh "potion_id $potion_id\n\n";
        print $fh "# Number of Caixa de Jornada boxes available\n";
        print $fh "has_jornada $has_jornada\n\n";
        print $fh "# Flag indicating if character needs to purchase potions (0 = no, 1 = yes)\n";
        print $fh "potion_need_purchase $potion_need_purchase\n\n";
        print $fh "# Job class for stat distribution (rogue/stalker)\n";
        print $fh "job_class $job_class\n";
        close $fh;
        
        print "[Heimdall::ConfigManager] Configuration saved successfully\n";
        return 1;
    } else {
        print "[Heimdall::ConfigManager] Error: Cannot write to $config_file\n";
        return 0;
    }
}

# Get a configuration value
sub getConfig {
    my $key = shift;
    
    if ($key eq 'hp_threshold') {
        return $hp_threshold;
    } elsif ($key eq 'potion_id') {
        return $potion_id;
    } elsif ($key eq 'has_jornada') {
        return $has_jornada;
    } elsif ($key eq 'potion_need_purchase') {
        return $potion_need_purchase;
    } elsif ($key eq 'job_class') {
        return $job_class;
    }
    
    return undef;
}

# Set a configuration value
sub setConfig {
    my ($key, $value) = @_;
    
    if ($key eq 'hp_threshold') {
        $hp_threshold = $value;
    } elsif ($key eq 'potion_id') {
        $potion_id = $value;
    } elsif ($key eq 'has_jornada') {
        $has_jornada = $value;
    } elsif ($key eq 'potion_need_purchase') {
        $potion_need_purchase = $value;
    } elsif ($key eq 'job_class') {
        $job_class = $value;
    } else {
        return 0;
    }
    
    return 1;
}

1; 
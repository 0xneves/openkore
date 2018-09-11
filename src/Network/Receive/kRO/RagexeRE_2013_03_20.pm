#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2013_03_20;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2012_06_18a);
use Globals qw (%ai_v $char %charSvrSet %equipSlot_lut %equipSlot_rlut %equipTypes_lut $messageSender $net %timeout);
use Log qw (message);
use Translation qw(T TF);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0999' => ['equip_item', 'a2 V v C', [qw(ID type viewID success)]], #11
		'099A' => ['unequip_item', 'a2 V C', [qw(ID type success)]],#9
		'099B' => ['map_property3', 'v a4', [qw(type info_table)]], #8
		'09A0' => ['sync_received_characters', 'V', [qw(sync_Count)]],#6
		'08C8' => ['actor_action', 'a4 a4 a4 V3 x v C V', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	
	my %handlers = qw(
		received_characters 099D
		received_characters_info 082D
		sync_received_characters 09A0
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

sub equip_item {
	my ($self, $args) = @_;
	my $item = $char->inventory->getByID($args->{ID});
	if ($args->{success}) {
		message TF("You can't put on %s (%d)\n", $item->{name}, $item->{binID});
	} else {
		$item->{equipped} = $args->{type};
		if ($args->{type} == 10 || $args->{type} == 32768) {
			$char->{equipment}{arrow} = $item;
		} else {
			foreach (%equipSlot_rlut){
				if ($_ & $args->{type}){
					next if $_ == 10; # work around Arrow bug
					next if $_ == 32768;
					$char->{equipment}{$equipSlot_lut{$_}} = $item;
					Plugins::callHook('equipped_item', {slot => $equipSlot_lut{$_}, item => $item});
				}
			}
		}
		message TF("You equip %s (%d) - %s (type %s)\n", $item->{name}, $item->{binID},
			$equipTypes_lut{$item->{type_equip}}, $args->{type}), 'inventory';
	}
	$ai_v{temp}{waitForEquip}-- if $ai_v{temp}{waitForEquip};
}

1;

=pod
//2013-03-20Ragexe (Judas)
packet_ver: 30
0x01FD,15,repairitem,2
0x086D,26,friendslistadd,2
0x0897,5,hommenu,2:4
0x0947,36,storagepassword,0
//0x0288,-1,cashshopbuy,4:8
0x086F,26,partyinvite2,2
0x0888,19,wanttoconnection,2:6:10:14:18
0x08c9,4
0x088E,7,actionrequest,2:6
0x089B,10,useskilltoid,2:4:6
0x0881,5,walktoxy,2
0x0363,6,ticksend,2
0x093F,5,changedir,2:4
0x0933,6,takeitem,2
0x0438,6,dropitem,2:4
0x08AC,8,movetokafra,2:4
0x0874,8,movefromkafra,2:4
0x0959,10,useskilltopos,2:4:6:8
0x085A,90,useskilltoposinfo,2:4:6:8:10
0x0898,6,getcharnamerequest,2
0x094C,6,solvecharname,2
0x0907,5,moveitem,2:4
0x0908,5
0x08CF,10 //Amulet spirits
0x08d2,10
0x0977,14 //Monster HP Bar
0x0998,8,equipitem,2:4
//0x0281,-1,itemlistwindowselected,2:4:8
0x0938,-1,reqopenbuyingstore,2:4:8:9:89
//0x0817,2,reqclosebuyingstore,0
//0x0360,6,reqclickbuyingstore,2
0x0922,-1,reqtradebuyingstore,2:4:8:12
0x094E,-1,searchstoreinfo,2:4:5:9:13:14:15
//0x0835,2,searchstoreinfonextpage,0
//0x0838,12,searchstoreinfolistitemclick,2:6:10
=cut

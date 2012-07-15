#  Copyright (C) 2011 Stanislav Sinyagin
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


# APC PowerNet SNMP-managed power distribution products
# MIB location:
#  ftp://ftp.apc.com/apc/public/software/pnetmib/mib/404/powernet404.mib
#
# Currently supported:
#   PDU firmware 5.x (tested with: AP8853 firmware v5.1.1)


package Torrus::DevDiscover::APC_PowerNet;

use strict;
use warnings;

use Torrus::Log;


$Torrus::DevDiscover::registry{'APC_PowerNet'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # PowerNet-MIB
     'apc_products' => '1.3.6.1.4.1.318.1',
     
     # rPDU2, the newer hardware and firmware
     'rPDU2IdentFirmwareRev' => '1.3.6.1.4.1.318.1.1.26.2.1.6',
     'rPDU2IdentModelNumber' => '1.3.6.1.4.1.318.1.1.26.2.1.8',
     'rPDU2IdentSerialNumber' => '1.3.6.1.4.1.318.1.1.26.2.1.9',

     'rPDU2DeviceConfigNearOverloadPowerThreshold' =>
     '1.3.6.1.4.1.318.1.1.26.4.1.1.8',

     'rPDU2DeviceConfigOverloadPowerThreshold' =>
     '1.3.6.1.4.1.318.1.1.26.4.1.1.9',

     'rPDU2DevicePropertiesNumOutlets' =>
     '1.3.6.1.4.1.318.1.1.26.4.2.1.4',

     'rPDU2DevicePropertiesNumPhases' =>
     '1.3.6.1.4.1.318.1.1.26.4.2.1.7',

     'rPDU2DevicePropertiesNumMeteredBanks' =>
     '1.3.6.1.4.1.318.1.1.26.4.2.1.8',

     'rPDU2DevicePropertiesMaxCurrentRating' =>
     '1.3.6.1.4.1.318.1.1.26.4.2.1.9',

     'rPDU2PhaseConfigNumber' => '1.3.6.1.4.1.318.1.1.26.6.1.1.3',

     'rPDU2PhaseConfigNearOverloadCurrentThreshold' =>
     '1.3.6.1.4.1.318.1.1.26.6.1.1.6',

     'rPDU2PhaseConfigOverloadCurrentThreshold' =>
     '1.3.6.1.4.1.318.1.1.26.6.1.1.7',

     'rPDU2BankConfigNumber' =>
     '1.3.6.1.4.1.318.1.1.26.8.1.1.3',

     'rPDU2BankConfigNearOverloadCurrentThreshold' =>
     '1.3.6.1.4.1.318.1.1.26.8.1.1.6',

     'rPDU2BankConfigOverloadCurrentThreshold' =>
     '1.3.6.1.4.1.318.1.1.26.8.1.1.7',


     # rPDU, the older hardware and firmware
     'sPDUIdentFirmwareRev'   => '1.3.6.1.4.1.318.1.1.4.1.2.0',
     'sPDUIdentModelNumber'   => '1.3.6.1.4.1.318.1.1.4.1.4.0',
     'sPDUIdentSerialNumber'  => '1.3.6.1.4.1.318.1.1.4.1.5.0',
     'rPDUIdentDeviceRating'  => '1.3.6.1.4.1.318.1.1.12.1.7.0',
     'rPDUIdentDeviceNumOutlets' => '1.3.6.1.4.1.318.1.1.12.1.8.0',
     'rPDUIdentDeviceNumPhases' => '1.3.6.1.4.1.318.1.1.12.1.9.0',

     'rPDULoadPhaseConfigNearOverloadThreshold' =>
     '1.3.6.1.4.1.318.1.1.12.2.2.1.1.3',
     'rPDULoadPhaseConfigOverloadThreshold' =>
     '1.3.6.1.4.1.318.1.1.12.2.2.1.1.4',
     
     );



my %rpdu2_system_oid;
foreach my $name
    ('rPDU2IdentFirmwareRev',
     'rPDU2IdentModelNumber',
     'rPDU2IdentSerialNumber',
     'rPDU2DeviceConfigNearOverloadPowerThreshold',
     'rPDU2DeviceConfigOverloadPowerThreshold',
     'rPDU2DevicePropertiesNumOutlets',
     'rPDU2DevicePropertiesNumPhases',
     'rPDU2DevicePropertiesNumMeteredBanks',
     'rPDU2DevicePropertiesMaxCurrentRating',
     )
{
    $rpdu2_system_oid{$name} = $oiddef{$name} . '.1';
}


my @rpdu_system_oid =
    ('sPDUIdentFirmwareRev', 'sPDUIdentModelNumber',
     'sPDUIdentSerialNumber', 'rPDUIdentDeviceRating',
     'rPDUIdentDeviceNumOutlets', 'rPDUIdentDeviceNumPhases');

    
my $apcInterfaceFilter = {
    'LOOPBACK' => {
        'ifType'  => 24,                     # softwareLoopback
    },
};



sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'apc_products',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
    {
        return 0;
    }

    $devdetails->setCap('interfaceIndexingPersistent');

    &Torrus::DevDiscover::RFC2863_IF_MIB::addInterfaceFilter
        ($devdetails, $apcInterfaceFilter);

    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();
    my $session = $dd->session();

    # check if rPDU2 is supported and retrieve system information
    {
        my $result = $session->get_request
            ( -varbindlist => [values %rpdu2_system_oid] );

        my $oid = $rpdu2_system_oid{'rPDU2IdentFirmwareRev'};
    
        if( defined($result) and
            defined($result->{$oid}) and length($result->{$oid}) > 0 )
        {
            $devdetails->setCap('apc_rPDU2');

            my $sysref = {};
            while( my($name, $oid) = each %rpdu2_system_oid )
            {
                $sysref->{$name} = $result->{$oid};
            }

            $data->{'param'}{'comment'} =
                'APC PDU ' .
                $sysref->{'rPDU2IdentModelNumber'} .
                ', Firmware ' .
                $sysref->{'rPDU2IdentFirmwareRev'} .
                ', S/N ' .
                $sysref->{'rPDU2IdentSerialNumber'};
            
            $data->{'param'}{'rpdu2-warn-pwr'} =
                $sysref->{'rPDU2DeviceConfigNearOverloadPowerThreshold'};
            
            $data->{'param'}{'rpdu2-crit-pwr'} =
                $sysref->{'rPDU2DeviceConfigOverloadPowerThreshold'};
            
            if( $devdetails->paramDisabled('suppress-legend') )
            {
                my $legend = $data->{'param'}{'legend'};
                $legend = '' unless defined($legend);

                $legend .= 'Phases:' .
                    $sysref->{'rPDU2DevicePropertiesNumPhases'} . ';';

                $legend .= 'Banks:' .
                    $sysref->{'rPDU2DevicePropertiesNumMeteredBanks'} . ';';

                $legend .= 'Outlets:' .
                    $sysref->{'rPDU2DevicePropertiesNumOutlets'} . ';';

                $legend .= 'Max current:' .
                    $sysref->{'rPDU2DevicePropertiesMaxCurrentRating'} . 'A;';
                
                $data->{'param'}{'legend'} = $legend;
            }
        }
    }

    if( $devdetails->hasCap('apc_rPDU2') )
    {
        # Discover PDU phases
        {
            my $cfnum = $dd->walkSnmpTable('rPDU2PhaseConfigNumber');
            my $warn_thr = $dd->walkSnmpTable
                ('rPDU2PhaseConfigNearOverloadCurrentThreshold');
            my $crit_thr = $dd->walkSnmpTable
                ('rPDU2PhaseConfigOverloadCurrentThreshold');

            while( my( $INDEX, $val ) = each %{$cfnum} )
            {
                $data->{'apc_rPDU2'}{'phases'}{$INDEX} = {
                    'rpdu2-phasenum' => $val,
                    'rpdu2-warn-currnt' => $warn_thr->{$INDEX},
                    'rpdu2-crit-currnt' => $crit_thr->{$INDEX},
                };
            }
        }

        # Discover PDU banks
        {
            my $cfnum = $dd->walkSnmpTable('rPDU2BankConfigNumber');
            my $warn_thr = $dd->walkSnmpTable
                ('rPDU2BankConfigNearOverloadCurrentThreshold');
            my $crit_thr = $dd->walkSnmpTable
                ('rPDU2BankConfigOverloadCurrentThreshold');

            while( my( $INDEX, $val ) = each %{$cfnum} )
            {
                $data->{'apc_rPDU2'}{'banks'}{$INDEX} = {
                    'rpdu2-banknum' => $val,
                    'rpdu2-warn-currnt' => $warn_thr->{$INDEX},
                    'rpdu2-crit-currnt' => $crit_thr->{$INDEX},
                };
            }
        }
    }
    else
    {
        # This is an old firmware, fall back to rPDU MIB
        my @oids;
        foreach my $oidname ( @rpdu_system_oid )
            
        {
            push( @oids, $dd->oiddef($oidname) );
        }
        
        my $result = $session->get_request( -varbindlist => \@oids );
        if( defined($result) )
        {
            my $sysref = {};
            foreach my $oidname ( @rpdu_system_oid )
            {
                my $oid = $dd->oiddef($oidname);
                my $val = $result->{$oid};
                if( defined($val) and length($val) > 0 )
                {
                    $sysref->{$oidname} = $val;
                }
                else
                {
                    $sysref->{$oidname} = 'N/A';
                }
            }

            $data->{'param'}{'comment'} =
                'APC PDU ' .
                $sysref->{'sPDUIdentModelNumber'} .
                ', Firmware ' .
                $sysref->{'sPDUIdentFirmwareRev'} .
                ', S/N ' .
                $sysref->{'sPDUIdentSerialNumber'};

            if( $devdetails->paramDisabled('suppress-legend') )
            {
                my $legend = $data->{'param'}{'legend'};
                $legend = '' unless defined($legend);

                $legend .= 'Phases:' .
                    $sysref->{'rPDUIdentDeviceNumPhases'} . ';';

                $legend .= 'Outlets:' .
                    $sysref->{'rPDUIdentDeviceNumOutlets'} . ';';

                $legend .= 'Max current:' .
                    $sysref->{'rPDUIdentDeviceRating'} . 'A;';
                
                $data->{'param'}{'legend'} = $legend;
            }
        }

        # Discover PDU phases
        {
            my $warn_thr = $dd->walkSnmpTable
                ('rPDULoadPhaseConfigNearOverloadThreshold');
            my $crit_thr = $dd->walkSnmpTable
                ('rPDULoadPhaseConfigOverloadThreshold');

            while( my( $INDEX, $val ) = each %{$warn_thr} )
            {
                $data->{'apc_rPDU'}{'phases'}{$INDEX} = {
                    'rpdu-phasenum' => $INDEX,
                    'rpdu-warn-currnt' => $val,
                    'rpdu-crit-currnt' => $crit_thr->{$INDEX},
                };
            }
        }

    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my $data = $devdetails->data();

    my @templates;
    if( $devdetails->hasCap('apc_rPDU2') )
    {
        push(@templates, 'APC_PowerNet::apc-pdu2-subtree');
    }
    else
    {
        push(@templates, 'APC_PowerNet::apc-pdu-subtree');
    }

    my $devParam = {
        'node-display-name' => 'PDU Statistics',
        'comment' => 'PDU current and power load',
        'precedence' => 10000,
    };
    
    my $pduSubtree =
        $cb->addSubtree( $devNode, 'PDU_Stats', $devParam, \@templates );
    
    my $precedence = 1000;
    
    if( $devdetails->hasCap('apc_rPDU2') )
    {
        # phases

        foreach my $INDEX ( sort {$a <=> $b}
                            keys %{$data->{'apc_rPDU2'}{'phases'}} )
        {
            my $ref = $data->{'apc_rPDU2'}{'phases'}{$INDEX};

            my $param = {
                'rpdu2-phase-index' => $INDEX,
                'node-display-name' => 'Phase ' . $ref->{'rpdu2-phasenum'},
                'precedence' => $precedence,
            };

            while (my($key, $val) = each %{$ref})
            {
                $param->{$key} = $val;
            }

            $cb->addSubtree
                ( $pduSubtree, 'Phase_' . $ref->{'rpdu2-phasenum'}, $param,
                  ['APC_PowerNet::apc-pdu2-phase'] );

            $precedence--;
        }

        # banks

        foreach my $INDEX ( sort {$a <=> $b}
                            keys %{$data->{'apc_rPDU2'}{'banks'}} )
        {
            my $ref = $data->{'apc_rPDU2'}{'banks'}{$INDEX};

            my $param = {
                'rpdu2-bank-index' => $INDEX,
                'node-display-name' => 'Bank ' . $ref->{'rpdu2-banknum'},
                'precedence' => $precedence,
            };

            while (my($key, $val) = each %{$ref})
            {
                $param->{$key} = $val;
            }

            $cb->addSubtree
                ( $pduSubtree, 'Bank_' . $ref->{'rpdu2-banknum'}, $param,
                  ['APC_PowerNet::apc-pdu2-bank'] );

            $precedence--;
        }
    }
    else
    {
        # Old rPDU MIB
        
        foreach my $INDEX ( sort {$a <=> $b}
                            keys %{$data->{'apc_rPDU'}{'phases'}} )
        {
            my $ref = $data->{'apc_rPDU'}{'phases'}{$INDEX};

            my $param = {
                'rpdu-phase-index' => $INDEX,
                'node-display-name' => 'Phase ' . $ref->{'rpdu-phasenum'},
                'precedence' => $precedence,
            };

            while (my($key, $val) = each %{$ref})
            {
                $param->{$key} = $val;
            }
            
            $cb->addSubtree
                ( $pduSubtree, 'Phase_' . $ref->{'rpdu-phasenum'}, $param,
                  ['APC_PowerNet::apc-pdu-phase'] );
            
            $precedence--;
        }        
    }

    return;
}





1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:

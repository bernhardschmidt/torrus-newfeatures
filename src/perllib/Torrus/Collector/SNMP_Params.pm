#  Copyright (C) 2002  Stanislav Sinyagin
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

# $Id$
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::Collector::SNMP_Params;

###  Initialize the configuration validator with module-specific parameters
###  Moved to a separate module to speed up the compiler initialization

my %validatorLeafParams =
    (
     'snmp-host'          => undef,
     'snmp-port'          => undef,
     '+domain-name'       => undef,
     'snmp-community'     => undef,
     'snmp-object'        => undef,
     'snmp-version'       => { '1'  => undef,
                               '2c' => undef },
     'snmp-timeout'       => undef,
     'snmp-retries'       => undef,
     'snmp-oids-per-pdu'  => undef,
     '+snmp-object-type'  => { 'OTHER'     => undef,
                               'COUNTER64' => undef },
     '+snmp-check-sysuptime' => { 'yes' => undef,
                                   'no'  => undef }
     );

sub initValidatorLeafParams
{
    my $hashref = shift;
    $hashref->{'ds-type'}{'collector'}{'collector-type'}{'snmp'} =
        \%validatorLeafParams;
}


my %admInfoLeafParams =
    (
     'snmp-host'          => undef,
     'snmp-port'          => undef,
     'domain-name'        => undef,
     'snmp-community'     => undef,
     'snmp-object'        => undef,
     'snmp-version'       => undef,
     'snmp-timeout'       => undef,
     'snmp-retries'       => undef,
     'snmp-oids-per-pdu'  => undef,
     'snmp-object-type'   => undef,
     'snmp-check-sysuptime' => undef
     );


my %admInfoParamCategories =
    (
     'snmp-host'          => 'SNMP',
     'snmp-port'          => 'SNMP',
     'domain-name'        => 'SNMP',
     'snmp-community'     => 'SNMP',
     'snmp-object'        => 'SNMP',
     'snmp-version'       => 'SNMP',
     'snmp-timeout'       => 'SNMP',
     'snmp-retries'       => 'SNMP',
     'snmp-oids-per-pdu'  => 'SNMP',
     'snmp-object-type'   => 'SNMP',
     'snmp-check-sysuptime' => 'SNMP'
     );


sub initAdmInfo
{
    my $map = shift;
    my $categories = shift;
    
    $map->{'ds-type'}{'collector'}{'collector-type'}{'snmp'} =
        \%admInfoLeafParams;
    
    while( ($pname, $category) = each %admInfoParamCategories )
    {
        $categories->{$pname} = $category;
    }
}



# These parameters may be expanded with $defs and %paramrefs%

$Torrus::ConfigTree::expand_params{'snmp-object'} = 1;
$Torrus::ConfigTree::expand_params{'ifindex-table'} = 1;
$Torrus::ConfigTree::expand_params{'snmp-host'} = 1;


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
package phpipam;

=head1 phpipam

phpipam - Module to work with the phpIPAM (phpipam.net) database

=head1 SYNOPSIS

    #!/usr/bin/env perl

    use strict;
    use warnings;
    use Data::Dumper;
    use phpipam;

    my $ipam = phpIPAM->new(
        dbhost => 'localhost',
        dbuser => 'phpipam',
        dbpass => 'phpipam',
        dbname => 'phpipam',
        dbport => 3306,
    );

    if(not $ipam) {
        print "ERROR could not create object\n";
        return -1;
    }

    my $ret = $ipam->getAllSubnets();

    print Dumper($ret);

    my $ipv4 = $ipam->getIP("173.194.70.100");
    print Dumper($ipv4);
    my $ipv6 = $ipam->getIP("2a00:1450:4001:c02::66");
    print Dumper($ipv6);
    exit(0);

=head1 INSTALLATION

These are the steps to install the module

    perl Makefile.PL
    make
    make install

=head1 DEPENDENCIES

phpipam have some dependencies to other modules

=head2 Required

    Carp
    DBI
    DBD::mysql
    Net::IP
    Exporter

=head1 DESCRIPTION

phpipam is a helper module to retrieve information from the phpipam database (phpipam.net)

=head2 EXPORT

None by default.

=head1 METHODS

=cut

use 5.018001;
use strict;
use warnings;
use Carp;
use DBI;
use Net::IP;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use phpipam ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

=head2 new()

Calling new() with valid options will automatically try and connect to the phpIPAM database. If successful, a blessed object is returned to the user.

    dbhost => [hostname|ip]     - DNS hostname or IP address (IPv4 or IPv6)
                                  of the remote phpIPAM MySQL database.
                                  ( Default: localhost )

    dbport => port              - Port number to connect to (1-65535).
                                  ( Default: 3306 )

    dbuser => string            - Username to use when authenticating to the
                                  MySQL database.
                                  ( Default: phpipam )

    dbpass => string            - Password to use when authenticating to the
                                  MySQL database.
                                  ( Default: phpipam )

    dbname => string            - Name of the MySQL database where phpIPAM
                                  stores all it's data.
                                  ( Default: phpipam )
=cut
sub new {

    my $class = shift;
    my $self = {};

    bless($self, $class);

    my (%args) = @_;
    $self->{ARGS} = \%args;

    $self->{CFG}->{DBHOST}          = $self->_arg("dbhost", "localhost");
    $self->{CFG}->{DBUSER}          = $self->_arg("dbuser", "phpipam");
    $self->{CFG}->{DBPASS}          = $self->_arg("dbpass", "phpipam");
    $self->{CFG}->{DBPORT}          = $self->_arg("dbport", 3306);
    $self->{CFG}->{DBNAME}          = $self->_arg("dbname", "phpipam");

    my $version = $self->_select("SELECT version FROM settings");
    return $self;
}

sub DESTROY {
    my $self = shift;

    $self->_sqldisconnect();
}
sub _arg {
    my $self = shift;
    my $arg = shift;
    my $default = shift;
    my $valid = shift;

    my $base = $self->{ARGS};

    my $val = (exists($base->{$arg}) ? $base->{$arg} : $default);

    if(defined ($valid)) {
        my $pass = 0;
        foreach my $check (@{$valid}) {
            $pass = 1 if($check eq $val);
        }

        if($pass == 0) {
            croak("Invalid value for setting '$arg' = '$val'.  Valid are: ['".join("','",@{$valid})."']");
        }

    }

    return $val;
}

sub _sqlconnect {
    my $self = shift;

    if($self->{DB}->{SOCK} and $self->{DB}->{SOCK}->ping) {
        return 0;
    }

    my $dsn = "DBI:mysql:".$self->{CFG}->{DBNAME}.":".$self->{CFG}->{DBHOST}.":".$self->{CFG}->{DBPORT};
    $self->{DB}->{SOCK} = DBI->connect($dsn, $self->{CFG}->{DBUSER}, $self->{CFG}->{DBPASS});

    if(not $self->{DB}->{SOCK}) {
        croak("Unable to connect to ".$self->{CFG}->{DBUSER}."@".$self->{CFG}->{DBHOST}.":".$self->{CFG}->{DBPORT}.": ".$DBI::errstr."\n");
    }
    return 0;
}
sub _sqldisconnect {
    my $self = shift;

    $self->{DB}->{SOCK}->disconnect();

    return 0;
}

sub _select {
    my $self = shift;
    my $query = $_[0];
    if(not $query ) {
        carp("Missing argument to _select()\n");
        return -1;
    }

    $self->_sqlconnect();

    my $results = $self->{DB}->{SOCK}->selectall_arrayref($query, { Slice => {} });
    if(not $results) {
        carp("Unable to execute \"$query\": ".$DBI::errstr."\n");
        return -1;
    }

    return $results;
}

sub _insert {
    my $self = shift;
    my $query = $_[0];
    if(not $query) {
        carp("Missing argument to _insert()\n");
        return -1;
    }

    $self->_sqlconnect();

    my $ra = $self->{DB}->{SOCK}->do($query);
    if(not $ra) {
        carp("Unable to execute \"$query\": ".$DBI::errstr."\n");
        return -1;
    }

    return $ra;
}
sub _update {
    my $self = shift;
    my $query = $_[0];
    if(not $query) {
        carp("Missing argument to _update()\n");
        return -1;
    }

    $self->_sqlconnect();

    my $ra = $self->{DB}->{SOCK}->do($query);
    if(not $ra) {
        carp("Unable to execute \"$query\": ".$DBI::errstr."\n");
        return -1;
    }

    return $ra;
}

sub _delete {
    my $self = shift;
    my $query = $_[0];
    if(not $query) {
        carp("Missing argument to _delete()\n");
        return -1;
    }

    $self->_sqlconnect();

    my $ra = $self->{DB}->{SOCK}->do($query);
    if(not $ra) {
        carp("Unable to execute \"$query\": ".$DBI::errstr."\n");
        return -1;
    }

    return $ra;
}

sub _escape {
    my $self = shift;
    my $q = $_[0];

    $q =~ s/'/\'/g;
    $q =~ s/--/\-\-/g;
    $q =~ s/\\/\\\\/g;

    return $q;
}

###########################################
# Functions to get stuff from phpIPAM db  #
###########################################

=head2 getAllSubnets()

Returns an array of hashes with each subnet stored in the database.
This function does not care about sections and relations between subnets.

    $phpipam->getAllSubnets();

If successful, returns a data structure similar to the one below:
    $VAR1 = [
          {
            'vrfId' => '0',
            'description' => 'Sample Subnet',
            'mask' => '16',
            'id' => '29',
            'subnet' => '176160768',
            'sectionID' => '4'
          },
        ];
Returns -1 if the query is unsuccessful for any reason.
=cut
sub getAllSubnets {
    my $self = shift;

    my $ret = $self->_select("SELECT id,subnet,mask,sectionID,description,vrfId FROM subnets");

    return $ret;
}

=head2 getSubnets(%opts)

Returns an array of hashes with each subnet within a section and/or vrf.

    $phpipam->getSubnets({vrf => "testvrf", section => "Servers");

Note that phpIPAM does not yet have any uniqueness checking on VRFs. This means
that multiple VRFs with the same name and the same RD may exist at the same time
within the phpIPAM database.
If 'vrf' is given as an option, getSubnets() will return the subnets from the first VRF
it matches in the database, all other VRFs are silently ignored.

If no options are given, getSubnets() behave just as getAllSubnets() do.
=cut
sub getSubnets {
    my $self = shift;
    my $opts = shift;
    my $section = $opts->{section} ||= undef;
    my $vrf = $opts->{vrf} ||= undef;
    my $strict = $opts->{strict} ||= undef;
    my $ipam_section = undef;
    my $ipam_vrf = undef;
    my $ipam_subnet = undef;

    if($section) {
        $ipam_section = $self->_select("SELECT id,name FROM sections WHERE name = \"".$self->_escape($section)."\"");
        if(not $ipam_section or @{$ipam_section} == 0) {
            carp("$section: No such section name found in database");
            return undef;
        }
    }

    if($vrf) {
        my $q = "SELECT vrfId,name FROM vrf WHERE name = \"".$self->_escape($vrf)."\" OR rd = \"".$self->_escape($vrf)."\"";
        $ipam_vrf = $self->_select($q);

        if(not $ipam_vrf) {
            carp("$vrf: No matching VRF found in database");
            return undef;
        }
    }

    my $s_query = "SELECT * FROM subnets";
    my @subnet_where;
    push(@subnet_where, "sectionId = ".$self->_escape(@{$ipam_section}[0]->{'id'})) if $section;
    push(@subnet_where, "vrfId = ".$self->_escape(@{$ipam_vrf}[0]->{'vrfId'})) if $vrf;
    push(@subnet_where, "vrfId = 0") if $strict and not $vrf;

    for (my $i=0; $i < @subnet_where; $i++) {
        $s_query .= $i ? " AND " : " WHERE ";
        $s_query .= $subnet_where[$i];
    }

    $ipam_subnet = $self->_select($s_query);

    return $ipam_subnet;
}

=head2 getAllSections()

Returns an array of hashes with each section stored in the database.

    $phpipam->getAllSections();

=cut
sub getAllSections {
    my $self = shift;

    my $ret = $self->_select("SELECT * FROM sections");

    return $ret;
}

=head2 getAllVrfs()

Returns an array of hashes with each VRF stored in the database.

    $phpipam->getAllVrfs();

=cut
sub getAllVrfs {
    my $self = shift;

    my $ret = $self->_select("SELECT * FROM vrf");

    return $ret;
}

=head2 getSiteTitle

Returns the site Title (what you see in the phpIPAM banner after logging in).

    $phpipam->getSiteTitle();

=cut

sub getSiteTitle {
    my $self = shift;

    my $title = $self->_select("SELECT siteTitle FROM settings");

    return @{$title}[0]->{siteTitle};
}

=head2 getIP($ip)

Returns a hash with information about a specific IP address.

    $phpipam->getIP("173.194.70.100");

If successful, returns a data structure similar to the one below:

    $VAR1 = [
          {
            'description' => 'An IP Address description',
            'id' => '92',
            'port' => '',
            'mac' => '',
            'owner' => 'Admin',
            'subnetId' => '29',
            'switch' => '',
            'state' => '1',
            'dns_name' => 'dns.as.seen.in.the.database.com'
          }
        ];
=cut
sub getIP {
    my $self = shift;
    my $ip = $_[0];
    my $netip;
    if(not $ip) {
        carp("Missing argument to getIP()\n");
        return -1;
    }

    if(not($netip = Net::IP->new($ip))) {
        carp("$ip is not a valid IP address\n");
        return -1;
    }

    my $ret_ip = $self->_select("SELECT id,subnetId,description,dns_name,mac,owner,state,switch,port FROM ipaddresses where ip_addr = \"".$netip->intip()."\"");
    if(not $ret_ip) {
        # No results
        return -1;
    }

    return $ret_ip;
}

=head2 getSubnet(%opts)

Return an array of hashes with information about the subnet(s) within the
given section and/or vrf.
Options are

    section => string           - Section name as stored in the database.
                                  Section names are case sensitive.

    subnet => CIDR              - IPv4 or IPv6 CIDR as stored in the database.
                                  NOTE: phpipam does not do any calculations
                                  on subnets, a subnet must exactly match what's in
                                  the database.
                                  This argument is MANDATORY.

    vrf => [name|RD]            - Name or Route-Distinguisher of the VRF to search in.

    $phpipam->getSubnet("192.168.0.0/24");

If more than one subnet is found (which is likely if no section or vrf is given),
getSubnet() will return an array with all subnets found.
=cut
sub getSubnet {
    my $self = shift;
    my $opts = shift;
    my $subnet = $opts->{subnet} ||= undef;
    my $section = $opts->{section} ||= undef;
    my $vrf = $opts->{vrf} ||= undef;
    my $ipam_section = undef;
    my $ipam_vrf = undef;
    my $ipam_subnet = undef;

    if(not $subnet) {
        carp("Missing mandatory option 'subnet'");
        return undef;
    }

    my $netip = Net::IP->new($subnet);
    if(not $netip) {
        carp("$subnet is not a valid subnet");
        return undef;
    }

    if($section) {
        $ipam_section = $self->_select("SELECT id,name FROM sections WHERE name = \"".$self->_escape($section)."\"");
        if(not $ipam_section or @{$ipam_section} == 0) {
            carp("$section: No such section name found in database");
            return undef;
        }
    }

    if($vrf) {
        my $q = "SELECT vrfId,name FROM vrf WHERE name = \"".$self->_escape($vrf)."\" OR rd = \"".$self->_escape($vrf)."\"";
        $ipam_vrf = $self->_select($q);

        if(not $ipam_vrf) {
            carp("$vrf: No matching VRF found in database");
            return undef;
        }
    }

    my $s_query = "SELECT * FROM subnets";
    my @subnet_where;
    push(@subnet_where, "subnet = '".$self->_escape($netip->intip)."' AND mask = ".$self->_escape($netip->prefixlen));
   push(@subnet_where, "sectionId = ".$self->_escape(@{$ipam_section}[0]->{'id'})) if $section;
    push(@subnet_where, "vrfId = ".$self->_escape(@{$ipam_vrf}[0]->{'vrfId'})) if $vrf;

    for (my $i=0; $i < @subnet_where; $i++) {
        $s_query .= $i ? " AND " : " WHERE ";
        $s_query .= $subnet_where[$i];
    }

    $ipam_subnet = $self->_select($s_query);

    return $ipam_subnet;
}

=head2 getVrf([$vrf|$rd])

Returns a single-element array with a hash containing all information about the given vrf.

    $phpipam->getVrf("testvrf");
    $phpipam->getVrf("123:123");

If more than one VRF is found with the given name, only the first match is returned.
getVrf() matches on name first, then RD. This means that if one VRF is stored in the database,
and another VRF is stored with an RD being the same as the first VRF name - trying to find
the VRF using RD can be quite difficult.

Consider this
    VRF1
        Name: 123:123
        RD:   weird-RD

    VRF2
        Name: AnotherVRF
        RD:   123:123

    $phpipam->getVrf("123:123");

In the above example, getVrf() will return only information about VRF1. If you want to be able to
distinguish between the VRFs, make sure that names and RDs do not collide in the database.
=cut
sub getVrf {
    my $self = shift;
    my $vrf = shift;

    if(not $vrf) {
        carp("Missing mandatory argument 'vrf' to getVrf()");
        return undef;
    }

    my $ipam_vrf = $self->_select("SELECT * FROM vrf WHERE name = '".$self->_escape($vrf)."' OR rd = '".$self->_escape($vrf)."'");
    if(not $ipam_vrf or @{$ipam_vrf} == 0) {
        carp("$vrf: No such VRF found in the database");
        return undef;
    }

    return [@{$ipam_vrf}[0]]; # Yep, this ain't pretty but it'll go for now.
}

=head2 getSection($section)

Returns a single-element array with a hash containing all information about the given section.

    $phpipam->getSection("TestSection");

=cut
sub getSection {
    my $self = shift;
    my $section = shift;

    if(not $section) {
        carp("Missing mandatory argument 'section' to getSection()");
        return undef;
    }

    my $ipam_section = $self->_select("SELECT * FROM sections WHERE name = '".$self->_escape($section)."'");
    if(not $ipam_section or @{$ipam_section} == 0) {
        carp("$section: No such section found in the database");
        return undef;
    }

    return [@{$ipam_section}[0]]; # Yep, this ain't pretty but it'll go for now.
}

=head2 getAddresses(%opts)

Returns an array of hashes with information about a all addresses within a specific
Section, VRF or subnet based on the given options

    section => string           - Section name as stored in the database.
                                  Section names are case sensitive.

    subnet => CIDR              - IPv4 or IPv6 CIDR as stored in the database.
                                  NOTE: phpipam does not do any calculations
                                  on subnets, a subnet must exactly match what's in
                                  the database.

    vrf => [name|RD]            - Name or Route-Distinguisher of the VRF to search in.

All options are optional, getAddresses will try its best to match addresses only found
within the section, subnet or vrf.

    $phpipam->getAddresses({section => "server", subnet => "10.0.0.0/8"});
    $phpipam->getAddresses({subnet => "172.16.0.0/24", vrf => "TestVRF"});

By default, getAddresses return all addresses of all sections and subnets if no options
are given.
=cut

sub getAddresses {
    my $self = shift;
    my $opts = shift;
    my $netip = undef;
    my $section = $opts->{section} ||= undef;
    my $vrf = $opts->{vrf} ||= undef;
    my $strict = $opts->{strict} ||= undef;
    my $filter = $opts->{filter} ||= undef;
    my $ipam_section = undef;
    my $ipam_subnet = undef;
    my $ipam_vrf = undef;
    my @address_filter;

    if($opts->{subnet}) {
        $netip = Net::IP->new($opts->{subnet});
        if(not $netip) {
            carp($opts->{subnet} ."is not a valid subnet");
            return undef;
        }
    }

    if($section) {
        $ipam_section = $self->_select("SELECT id,name FROM sections WHERE name = \"".$self->_escape($section)."\"");
        if(not $ipam_section or @{$ipam_section} == 0) {
            carp("$section: No such section name found in database");
            return undef;
        }
    }

    if($vrf) {
        my $q = "SELECT vrfId,name FROM vrf WHERE name = \"".$self->_escape($vrf)."\" OR rd = \"".$self->_escape($vrf)."\"";
        $ipam_vrf = $self->_select($q);

        if(not $ipam_vrf) {
            carp("$vrf: No matching VRF found in database");
            return undef;
        }
    }

    my $s_query = "SELECT id FROM subnets";
    my @subnet_where;
    push(@subnet_where, "subnet = '".$self->_escape($netip->intip)."' AND mask = ".$self->_escape($netip->prefixlen)) if $netip;
    push(@subnet_where, "sectionId = ".$self->_escape(@{$ipam_section}[0]->{'id'})) if $section;
    push(@subnet_where, "vrfId = ".$self->_escape(@{$ipam_vrf}[0]->{'vrfId'})) if $vrf;
    push(@subnet_where, "vrfId = 0") if $strict and not $vrf;

    if(defined $filter) {
      foreach my $k (keys(%{$filter})) {
        push(@address_filter, $self->_escape($k)." = '".$self->_escape($filter->{$k})."'");
      }
    }

    for (my $i=0; $i < @subnet_where; $i++) {
        $s_query .= $i ? " AND " : " WHERE ";
        $s_query .= $subnet_where[$i];
    }

    $ipam_subnet = $self->_select($s_query);

    if((not $ipam_subnet or @{$ipam_subnet} == 0) and $netip) {
        carp("No matching subnets found");
        return undef;
    }elsif(not $ipam_subnet or @{$ipam_subnet} == 0) {
        return [];
    }

    my $q = "SELECT * FROM ipaddresses";
    $q .= " WHERE (subnetId = ".(shift(@{$ipam_subnet}))->{'id'} if @{$ipam_subnet};
    foreach my $s (@{$ipam_subnet}) {
        $q .= " OR subnetId = ".$s->{'id'};
    }
    $q .= ")";

    for (my $i=0; $i < @address_filter; $i++) {
        $q .= " AND ";
        $q .= $address_filter[$i];
    }

    my $subnets = $self->_select($q);

    return $subnets;
}
1;
__END__
=head1 SEE ALSO

phpIPAM official homepage - http://phpipam.net

=head1 AUTHOR

Diddi Oscarsson, E<lt>diddi@diddi.seE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Diddi Oscarsson

The MIT License (MIT)
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut

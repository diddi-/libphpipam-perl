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

    my $supported_phpIPAM = "0.8";

    bless($self, $class);

    my (%args) = @_;
    $self->{ARGS} = \%args;

    $self->{CFG}->{DBHOST}          = $self->_arg("dbhost", "localhost");
    $self->{CFG}->{DBUSER}          = $self->_arg("dbuser", "phpipam");
    $self->{CFG}->{DBPASS}          = $self->_arg("dbpass", "phpipam");
    $self->{CFG}->{DBPORT}          = $self->_arg("dbport", 3306);
    $self->{CFG}->{DBNAME}          = $self->_arg("dbname", "phpipam");

    my $version = $self->_select("SELECT version FROM settings");
    if(not @{$version}[0]->{version} eq $supported_phpIPAM) {
        croak("This module only supports phpIPAM version $supported_phpIPAM (connected to version ".@{$version}[0]->{version}.")");
    }
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
    my $ipam_section = undef;
    my $ipam_subnet = undef;
    my $ipam_vrf = undef;

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
    push(@subnet_where, "subnet = ".$self->_escape($netip->intip)." AND mask = ".$self->_escape($netip->prefixlen)) if $netip;
    push(@subnet_where, "sectionId = ".$self->_escape(@{$ipam_section}[0]->{'id'})) if $section;
    push(@subnet_where, "vrfId = ".$self->_escape(@{$ipam_vrf}[0]->{'vrfId'})) if $vrf;

    for (my $i=0; $i < @subnet_where; $i++) {
        $s_query .= $i ? " AND " : " WHERE ";
        $s_query .= $subnet_where[$i];
    }

    $ipam_subnet = $self->_select($s_query);

    if(not $ipam_subnet or @{$ipam_subnet} == 0) {
        carp("No matching subnets found");
        return undef;
    }

    my $q = "SELECT * FROM ipaddresses";
    $q .= " WHERE subnetId = ".(shift(@{$ipam_subnet}))->{'id'} if @{$ipam_subnet};
    foreach my $s (@{$ipam_subnet}) {
        $q .= " OR subnetId = ".$s->{'id'};
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

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.1 or,
at your option, any later version of Perl 5 you may have available.



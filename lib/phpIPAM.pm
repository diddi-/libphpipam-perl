
package phpIPAM;

use strict;
use Carp;
use DBI;
use Net::IP qw ( ip_is_ipv4 ip_is_ipv6 ip_bintoint ip_iptobin ip_get_version);
use vars qw ( $VERSION );

$VERSION = '0.1';

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

###########################################
# Functions to get stuff from phpIPAM db  #
###########################################

## getAllSubnets()
# Return an array with hashes of all available subnets in phpIPAM db
##
sub getAllSubnets {
    my $self = shift;

    my $ret = $self->_select("SELECT id,subnet,mask,sectionID,description,vrfId FROM subnets");

    return $ret;
}

## getIP()
# Return a hash with information about a specific IP
# Params:
#   ip      - The ip address to return information about
##
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

1;

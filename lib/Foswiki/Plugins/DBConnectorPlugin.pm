#!/usr/local/bin/perl -wI.
#
# This script Copyright (c) 2008 Impressive.media 
# and distributed under the GPL (see below)
#
# Based on parts of GenPDF, which has several sources and authors
# This script uses html2pdf as backend, which is distributed under the LGPL
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html

# =========================
package Foswiki::Plugins::DBConnectorPlugin;    # change the package name and $pluginName!!!
# =========================
# Always use strict to enforce variable scoping
use strict;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use DBI;
use Error qw(:try);


# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $DBC_con);
# This should always be $Rev: 12445$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 12445$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.1';

# Short description of this plugin
# One line description, is shown in the %FoswikiWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Provides a connection to a external DB to easy store editional topic-based data';

# Name of this Plugin, only used in this module
$pluginName = 'DBConnectorPlugin';

# =========================



sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # Plugin correctly initialized
    _connect();
    return 1;
}

sub _debug
{
    my $message = shift;
    TWiki::Func::writeDebug("[DBConnectorPlugin]:".$message ) if $Foswiki::cfg{Plugins}{DBConnectorPlugin}{Debug};
}

sub _warn
{
	my $message = shift;
    return TWiki::Func::writeWarning( $message );
}


sub _connect {
	my $driver = $Foswiki::cfg{Plugins}{DBConnectorPlugin}{driverPackage};
	# TODO: use the $Foswiki::cfg{Plugins}{DBConnectorPlugin}{driverPackage} here
	use DBD::SQLite;
    my $dsn = $Foswiki::cfg{Plugins}{DBConnectorPlugin}{dsn};
    if(!DBI->parse_dsn($dsn)) {
    	_warn("the given DSN( $Foswiki::cfg{Plugins}{DBConnectorPlugin}{dsn} ) is not parseable. Is it correct: $dsn");
    	return undef;
    }
    my $user = $Foswiki::cfg{Plugins}{DBConnectorPlugin}{Username};
    my $password = $Foswiki::cfg{Plugins}{DBConnectorPlugin}{Password};    

    my $DBC_con = DBI->connect(
        $dsn, $user, $password,
        {
        RaiseError => 1,
        PrintError => 1,
        FetchHashKeyName => NAME_lc =>
        @_
        }
    );
    unless (defined $DBC_con) {
    	my $error = "DBConnector could not connvet to $driver, error: $DBI::errstr";
    	_debug($error);    	   
        throw Error::Simple($error);
    }        

    return $DBC_con;
}

sub _disconnect
{
	_debug("disconnecting");	
    # diconnect
    $DBC_con->disconnect;
}

sub getValues{
	my ( $web, $topic, @values ) = @_;
	if (@values < 1) {
		_warn("could not get values from $web.$topic because no fields given");		
		return undef;		
	}
	my $fields = join(",",@values);
	my $qry = "qq(SELECT ? FROM ? where topic_id = ?"; 
    my $qryobj = $DBC_con->prepare($qry);
    $qryobj->execute($fields,$web,$topic) or _warn("could not send query: $qry, error:".$qryobj->err);
    my %result = $qryobj->fetchrow_hashref();    
    $qryobj->finish;
    # returning the values as {fieldname} = value pairs. If no row could be fetched, this result is undef
    return %result;
}

1;
# vim: ft=perl foldmethod=marker
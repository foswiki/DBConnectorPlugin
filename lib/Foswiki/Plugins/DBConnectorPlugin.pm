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
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );
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
our $DBC_con;
our $TableKeyField;
our $curWeb;
our $curTopic;
our $curUser;

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;
    
    Foswiki::Func::registerRESTHandler('createdb', \&_createDB) if($Foswiki::cfg{Plugins}{DBConnectorPlugin}{allowCreatedb});
     
    $TableKeyField = $Foswiki::cfg{Plugins}{DBConnectorPlugin}{TableKeyField};
    # Plugin correctly initialized
    _connect();
    $curWeb = $web;
    $curTopic = $topic;
    $curUser = $user;
    return 1;
}

=begin TML

---+++ getValues( $web, $topic, @fields ) -> ( %result )

get values for out of the database 
   * =$web= - Web name, required, will be used as table
   * =$topic= Topic name, required, will be used as identifier/key
   * =$fields= - reference on an array of field names, optional. This fields are fetched out of the db
   * =$checkAccess= if this is zero, access is not checked
Return: =( %result )= Result, a hash with each fetched field-name as ke

if you want to fetch fields ('samplefield1','samplefield2') from System.WebHome you call it :
<pre>my %result getValues("System",'WebHome',('samplefield1','samplefield2'));
accessing results this way
print %result->{'bar'};
</pre>
=cut
sub getValues{
	my $web = shift;
	my $topic = shift;
	my $fields = shift;
	my $checkAccess = shift || 1;
	my @fields = @{$fields};
	_debug("Getting values for$web.Topic - fields:", @fields);
	if($checkAccess && !_hasAccess("VIEW")) {
        # no access;
        return;     
    }
    
	if (@fields < 1) {
		#_warn("could not get values from $web.$topic because no fields given");		
		#return undef;
		
		# get all fields
		@fields = ('*');	
	}
	my $fields = join(",",@fields);
	my $qry = qq(SELECT $fields FROM `$web` where `$TableKeyField` = '$topic');	
	_debug("Query: $qry");
    my $qryobj = $DBC_con->prepare($qry);
    
    unless ($qryobj) {
    	_warn("could not send query, maybe table missing?"); 
    	return undef;
    }
    $qryobj->execute() or _warn("could not send query: $qry, error:".$qryobj->err);    
    my $result = $qryobj->fetchrow_hashref();   

    # returning the values as {fieldname} = value pairs. If no row could be fetched, this result is undef
    _debug("Returned values:", values(%{ $result }));
    $qryobj->finish;
    return %{ $result };
}


=begin TML

---+++ updateValues( $web, $topic, $fiedValuePairs  ) -> ( )

get values for out of the database 
   * =$web= - Web name, required, will be used as table
   * =$topic= Topic name, required, will be used as identifier/key
   * =$fiedValuePairs= reference to a hash, which has the field-name as key and the hash-value as field-value
   * =$checkAccess= if this is zero, access is not checked
Return: -

if you want to update fields ('samplefield1','samplefield2') from System.WebHome you call it :
<pre>
my %pairs;
%pairs->{'samplefield1'} = 20;
%pairs->{'samplefield2'} = "myvalue1";
# Attention, you must use a reference!
updateValues("System",'WebHome',\%pairs);
</pre>
=cut
sub updateValues {
	my $web = shift;
    my $topic = shift;
    my $fiedValuePairs = shift;
    my $checkAccess = shift || 1;
	_debug("Updating values inserted",keys %{$fiedValuePairs});
    if($checkAccess && !_hasAccess("CHANGE")) {
        # no access;
        return undef;     
    }
    _createEntryForTopicIfNotExitent($web,$topic);	
	# craete a field list with placeholder(?), while each field is surrounded by `
	my $values ="`". join("`=?,`", keys %{$fiedValuePairs}) . "`=?";	
    my $qry = qq(UPDATE $web SET $values WHERE `$TableKeyField`='$topic' );  

    _debug("Query: $qry");
    my $qryobj = $DBC_con->prepare($qry);
    unless ($qryobj) { 
    	_warn("could not prepare qry ($qry), table missing? \nerror:".$DBC_con->errstr);
    	return;
    }
    # now insert the values for the placeholders into the query
    $qryobj->execute(values %{$fiedValuePairs}) or _warn("could not insert values for $web.$topic \nerror:".$qryobj->err);
    $qryobj->finish();
    _debug("Values upated");
}

sub _createEntryForTopicIfNotExitent {
	my ( $web, $topic ) = @_;
	_debug("Creating topic entry if not existent");
	my $created = 0;
	if(!getValues($web,$topic,["topic_id"],0)) {
		my $qry = "INSERT into $web (`$TableKeyField`) VALUES ('$topic')";
		_debug("Inserting values: $qry");
		$created = $DBC_con->do( $qry);		
	}
	# somehow this is not working. Any ideas?
	# my $created = $DBC_con->do( "IF NOT EXISTS (SELECT `$TableKeyField` FROM $web WHERE `$TableKeyField` = $topic' ) begin INSERT $web set (`$TableKeyField`) VALUES ('$topic') end ELSE BEGIN END" );	
}



=begin TML

---+++ _createDB( $session  ) -> ( )

if you want to create a initial table for a web, where informations can be stored for topics, you got to run this rest handler to initialize/create it. The query defined on topic Syste.DBConnectorPluginCreateTableQuery is used as a template for the query.
   * %TABLENAME% gets expanded to the corresponding Web, when you create the table;
   * %TOPICNAME% gets expanded to the topic. This should be actually always be a existing topic. In normal cases, this value is not needed in the template#
   * %DBCONTABLEKEYFIELD% gets expanded to the primary key which is defined in the Configuration-Center $Foswiki::cfg{Plugins}{DBConnectorPlugin}{TableKeyField}
<em>_you can disallow the creatinof table with unchecking $Foswiki::cfg{Plugins}{DBConnectorPlugin}{allowCreatedb} in the Configuration-Center _</em>
you call the rest handler this way, creating a data for the web "TheWeb"
<pre>%SCRIPTURL{"rest"}%/DBConnectorPlugin/createdb?topic=TheWeb.WebHome </pre>

__ Attention: If the table exists allready, it will not be touched. No data will be erase or even a other table created __
=cut
sub _createDB {
    # TODO: test if there is allready a database, if yes, do not create anything and cancel
    my $session = shift;    
    my $web = $session->{webName};
    my $topic = $session->{topicName};
    _warn("Creating table for Web:$web");
    my ($meta, $qrytext ) = Foswiki::Func::readTopic( "System", "DBConnectorPluginCreateTableQuery" );
    
    if($qrytext eq "") {
    	_warn("could not create table $web, no query defined in topic System.DBConnectorPluginCreateTableQuery:");
        throw Foswiki::OopsException( 'attention',
                                       def => "generic",
                                       web => $web,
                                       topic => $topic,
                       keep => 1,
                                       params => [ "could not create table $web, no query defined in topic System.DBConnectorPluginCreateTableQuery"] 
                      );
    } 

    # expanding $WEB$ and $TOPIC$ and $TABLEKEYFIELD$
    $qrytext =~ s/%TABLENAME%/$web/im;
    $qrytext =~ s/%TOPICNAME%/$topic/im;
    $qrytext =~ s/%DBCONTABLEKEYFIELD%/$TableKeyField/im;

    if(!getValues($web,$topic,[$TableKeyField],0)) {
         sendQry ($qrytext );
    }
    
    if($DBC_con->errstr ne "") {
    	_warn("could not create table $web, error:".$DBC_con->errstr);
    	throw Foswiki::OopsException( 'attention',
                                       def => "generic",
                                       web => $web,
                                       topic => $topic,
                       keep => 1,
                                       params => [ "could not create table $web, error:".$DBC_con->errstr, "","",""] 
                      );
    }    
    # else
    throw Foswiki::OopsException( 'attention',
                                       def => "generic",
                                       web => $web,
                                       topic => $topic,
                       keep => 1,
                                       params => [ "The table $web has been successfully created.", "","",""] 
                      );
    # bad as no feedback, other solutions?
    # my $url = Foswiki::Func::getViewUrl( $curWeb, $curTopic );
    # $session->redirect($url,0);
    return 1;
    #print $cgiQuery->redirect($url);
}


=begin TML
---+++ sendQry( $query  ) -> ( $results)

use this method to simply run querys on the database. You get a result like described by getValues 
   * $query Complete SQL query;
Return: returning a hash which has an the topic-identiefer as key for each row fetch, for each of this values a hash is stored, by {fieldname} = value like in getValues
=cut

sub sendQry {
    my $qry = shift;
    # TODO: add access control? how?
    my $qryobj = $DBC_con->prepare($qry);
    my $results;
    unless ($qryobj) { 
        _warn("could not prepare qry ($qry), table missing? \nerror:".$DBC_con->errstr);
        return $results;
    }
    
    _debug("Runnging direct query '$qry'");
    # now insert the values for the placeholders into the query
    $qryobj->execute() or _warn("could not run direct query".$qry);
    $results = $qryobj->fetchall_hashref($TableKeyField); 
    # returning the values as {fieldname} = value pairs. If no row could be fetched, this result is undef
    _debug("Returned values:", values(%{ $results }));
    $qryobj->finish;
    return %{$results};
}

sub deleteEntry{
	my $web = shift;
    my $topic = shift;
    my $checkAccess = shift || 1;
    if($checkAccess && !_hasAccess("CHANGE")) {
        # no access;
        return;     
    }

	$DBC_con->do("DELETE from `$web` where `$TableKeyField`='$topic'");	
}


sub afterRenameHandler {
    my ( $oldWeb, $oldTopic, $oldAttachment,
         $newWeb, $newTopic, $newAttachment ) = @_;
    
    # we need to move the whole entry to a other table ( as each web has its own table)
    if($oldWeb ne $newWeb) {
        # get the row with all fields
        my %oldValues = getValues($oldWeb,$oldTopic,["*"]);
        # delete entry in old table
        deleteEntry($oldWeb,$oldTopic);
        # create new entry om the new table ( for the new web)
        %oldValues->{$TableKeyField} = $newTopic;
        updateValues($newWeb,$newTopic, \%oldValues,0);       
    }
    # just update the primary key to the new value
    else {
        my %values;     
        %values->{$TableKeyField} = $newTopic; 
        updateValues($oldWeb,$oldTopic, \%values,0);      
    }
    my $updateOnChangeWebList = $Foswiki::cfg{Plugins}{DBConnectorPlugin}{UpdateOnChangeWebList};
    # is the handler disabled ( so empty )
    if($updateOnChangeWebList ne "") {
        my @webs;
        # no, so lets update the webs
        # * is for "all"
        if($updateOnChangeWebList eq "*") {
            @webs = Foswiki::Func::getListOfWebs();         
        }
        # its a ; separated list of webs
        else {
            @webs = split(";",$updateOnChangeWebList );
            
        } 
        
        _updateLinksInWebs($oldWeb, $oldTopic, $newWeb, $newTopic,\@webs);       
    }    
}

sub _updateLinksInWebs {
    my ($oldWeb, $oldTopic, $newWeb, $newTopic,$toUpdateWebs) = @_;
    my @webs = @{$toUpdateWebs};
    my @fieldlist = split(";",$Foswiki::cfg{Plugins}{DBConnectorPlugin}{UpdateOnInvolveFiedlsList});
    my $pattern = '%'.$oldTopic.'%';
    for(my $i = 0; $i < @fieldlist;$i++) {
        @fieldlist[$i] = "`".@fieldlist[$i]."` LIKE '$pattern'";      
    }
    foreach my $curWeb (@webs) {
        #get all entries needing an update
        my %topicsNeedUpdates = sendQry("SELECT * FROM $curWeb WHERE ".join(" OR ", @fieldlist));
        
        # go trough all topics needs an update
        if(%topicsNeedUpdates) {
	        foreach my $topicid (keys %topicsNeedUpdates) {
	            # check all fields and update its data accordningly
	            foreach my $field (keys %{%topicsNeedUpdates->{$topicid}}) {
	            	_debug("fixing links in:\n".%topicsNeedUpdates->{$topicid}{$field});
	                %topicsNeedUpdates->{$topicid}{$field} = _updateLinksInString($oldWeb,$oldTopic, $newWeb, $newTopic,%topicsNeedUpdates->{$topicid}{$field});
	                _debug("fixed string is:\n".%topicsNeedUpdates->{$topicid}{$field});
	            }
	            # update the entry in the DB. DB name is the current web, the identifier 
	            updateValues($curWeb,$topicid, \%topicsNeedUpdates->{$topicid},0);              
	        }  
        }     
    }
}

sub _updateLinksInString {
    my ($oldWeb, $oldTopic, $newWeb, $newTopic, $string) = @_;
    # TODO: this one should be checked for really working properly -> unit test
    $string =~ s/$oldWeb.$oldTopic/$newWeb.$newTopic/g;
    $string =~ s/$oldWeb\/$oldTopic/$newWeb\/$newTopic/g;
    $string =~ s/$oldTopic/$newTopic/g;
    return $string;
}

sub _debug
{   
    return if !$Foswiki::cfg{Plugins}{DBConnectorPlugin}{Debug};
    my ($message,@param) = @_;

    TWiki::Func::writeDebug("[DBConnectorPlugin]:".$message ) ;
    if(@param > 0) {
        foreach my $p (@param) {
            TWiki::Func::writeDebug("[DBConnectorPlugin]://Param:".$p ) ;           
        }
    }
    TWiki::Func::writeDebug("[DBConnectorPlugin]:----------\n" ) ;
}

sub _warn
{
    my $message = shift;  
    _debug($message);  
    return TWiki::Func::writeWarning( $message );
}

sub _hasAccess{
    my ($web,$topic, $type);
    if(Foswiki::Func::checkAccessPermission($type, $curUser, undef, $topic, $web, undef)) {
        # has acess
       return 1;    
    }   
    # else  
    _warn("Warning, $curUser tried to get access to a topic without having proper permissions( $type )");
    return 0;   
}

sub _connect {
    my $driver = $Foswiki::cfg{Plugins}{DBConnectorPlugin}{driverPackage};  
    eval "require $driver;";

    my $dsn = $Foswiki::cfg{Plugins}{DBConnectorPlugin}{dsn};
    my $workingarea = Foswiki::Func::getWorkArea("DBConnectorPlugin");
    $dsn =~ s/%WORKINGAREA%/$workingarea/im;
    
    if(!DBI->parse_dsn($dsn)) {
        _warn("the given DSN( $Foswiki::cfg{Plugins}{DBConnectorPlugin}{dsn} ) is not parseable. Is it correct: $dsn");
        return undef;
    }
    _debug("connecting to $dsn..");
    $DBC_con = DBI->connect(
        $dsn, "","",
        {
        #RaiseError => 1,
        #PrintError => 1,
        FetchHashKeyName => NAME_lc =>
        @_
        }
    );
    unless (defined $DBC_con) {
        my $error = "DBConnector could not connvet to $driver, error: $DBI::errstr";
        _debug($error);        
        throw Error::Simple($error);
    }        
    _debug("connection successfully");
    
}

sub _disconnect
{
    _debug("disconnecting");    
    # diconnect
    $DBC_con->disconnect;
}

1;
# vim: ft=perl foldmethod=marker
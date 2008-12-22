# ---+ DBConnectorPlugin
# This is the configuration used by the <b>DBConnectorPlugin</b> and the
# <h2>Database</h2>
# **STRING**
# perl driver package
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{driverPackage} = "DBD::SQLite";

# **STRING**
# DBI dsn. if you include the string %WORKINGAREA% it gets expanded to the Foswiki working directory for the plugin. This should be working/working_areas/DBConnectorPlugin
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{dsn} = "dbi:SQLite:dbname=%WORKINGAREA%/foswiki.db";

# **STRING**
# primary key ( typically be a varchar(255) or similar) which is used to identify the topic 
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{TableKeyField} = "topic_id";

# **BOOLEAN**
# allow calling the "createdb" rest handler. Attention, this can delete your data, so deactivate after installing!
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{allowCreatedb} = 1;

# <h2>Link update, database updates</h2>
# **STRING**
# Semilicolon separated list of table-fields. If a topic gets renamed, the DBConnectorPlugin searches all fields you define here in all webs you define in the next option. Links referencing this renamed topic are updated like we are used to in Foswiki.
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{UpdateOnInvolveFiedlsList} = "samplefield2";

# **STRING**
# List of webs ( tables ) to include for updating fields, when a topic gets renamed. Use wildcard * for updating all webs or use a semicolon separated list.  Leave _Empty_ for skipping ( performance )
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{UpdateOnChangeWebList} = "*";

# <h2>Logging</h2>
# **BOOLEAN**
# enable debuugin
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{Debug} = 0;


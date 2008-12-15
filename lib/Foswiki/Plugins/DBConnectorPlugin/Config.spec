, fo# ---+ DBConnector Plugin
# This is the configuration used by the <b>ToPDFPlugin</b> and the
# <h2>Connection</h2>

# **STRING**
# perl driver package
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{driverPackage} = "DBD::SQLite;dbname=/tmp/testdb";

# **STRING**
# DBI dsn
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{dsn} = "dbi:SQLite";

# **User**
#  Username for the connection
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{User} = "-User-";

# **Password**
# Password for the connectionory
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{Password} = "-Password-";

# **BOOLEAN**
# path to your ttf fonts  reporsitory
$Foswiki::cfg{Plugins}{DBConnectorPlugin}{Debug} = 0;


# Basic test to check that OLE::Storage_Lite loads.
BEGIN { $| = 1; print "1..1\n"; }

use OLE::Storage_Lite;
$loaded = 1;
print "ok 1\n";

END {print "not ok 1\n" unless $loaded;}

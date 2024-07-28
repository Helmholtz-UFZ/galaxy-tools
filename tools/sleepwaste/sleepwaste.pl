$mem = $ARGV[1] * 1024 * 1024;

my $numbers = "";
$numbers .= pack("N", $_) for (1..$mem);

use PDL;
$array= sequence(long, $mem);

# @array = (1 .. $mem);

sleep $ARGV[0];

print "slept for $ARGV[0] s and allocated $ARGV[1] MB in an array\n";

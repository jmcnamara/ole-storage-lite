#!/usr/bin/perl -w

###############################################################################
#
# Tests for OLE::Storage_Lite basic operations.
#
# Tests reading OLE files, PPS tree operations, and basic functionality.
#
use strict;
use Test::More tests => 26;
use OLE::Storage_Lite;

# Test module loading.
BEGIN { use_ok( 'OLE::Storage_Lite' ) }

# Test constants.
is( OLE::Storage_Lite::PpsType_Root(),  5,      'PpsType_Root constant' );
is( OLE::Storage_Lite::PpsType_Dir(),   1,      'PpsType_Dir constant' );
is( OLE::Storage_Lite::PpsType_File(),  2,      'PpsType_File constant' );
is( OLE::Storage_Lite::DataSizeSmall(), 0x1000, 'DataSizeSmall constant' );
is( OLE::Storage_Lite::LongIntSize(),   4,      'LongIntSize constant' );
is( OLE::Storage_Lite::PpsSize(),       0x80,   'PpsSize constant' );

# Test constructor with valid file.
my $ole = OLE::Storage_Lite->new( 't/files/test1.xls' );
isa_ok( $ole, 'OLE::Storage_Lite', 'Constructor returns correct object' );

# Test getPpsTree() without data.
my $pps_root = $ole->getPpsTree();
isa_ok(
    $pps_root,
    'OLE::Storage_Lite::PPS::Root',
    'getPpsTree returns Root object'
);
ok( defined $pps_root, 'getPpsTree returns defined value' );
is( $pps_root->{Type}, 5, 'Root PPS has correct type' );

# Test getPpsTree with data.
my $pps_root_data = $ole->getPpsTree( 1 );
isa_ok(
    $pps_root_data,
    'OLE::Storage_Lite::PPS::Root',
    'getPpsTree with data returns Root object'
);
ok( defined $pps_root_data->{Data}, 'Root PPS with data has Data property' );

# Test that the root has children.
ok( defined $pps_root->{Child}, 'Root PPS has children' );
isa_ok( $pps_root->{Child}, 'ARRAY', 'Root children is an array reference' );
ok( scalar @{ $pps_root->{Child} } > 0, 'Root has at least one child' );

# Test basic PPS properties.
ok( defined $pps_root->{Name},       'Root PPS has Name property' );
ok( defined $pps_root->{No},         'Root PPS has No property' );
ok( defined $pps_root->{StartBlock}, 'Root PPS has StartBlock property' );
ok( defined $pps_root->{Size},       'Root PPS has Size property' );

# Test child PPS properties.
my $first_child = $pps_root->{Child}->[0];
ok( defined $first_child->{Name}, 'First child has Name property' );
ok( defined $first_child->{Type}, 'First child has Type property' );
ok( $first_child->{Type} == 1 || $first_child->{Type} == 2,
    'First child type is DIR or FILE' );

# Test getNthPps.
my $pps_0 = $ole->getNthPps( 0 );
isa_ok(
    $pps_0,
    'OLE::Storage_Lite::PPS::Root',
    'getNthPps(0) returns Root object'
);

my $pps_0_data = $ole->getNthPps( 0, 1 );
isa_ok(
    $pps_0_data,
    'OLE::Storage_Lite::PPS::Root',
    'getNthPps(0, 1) returns Root object with data'
);

# Test constructor with non-existent file.
my $ole_bad = OLE::Storage_Lite->new( 'nonexistent.xls' );
isa_ok( $ole_bad, 'OLE::Storage_Lite',
    'Constructor with bad file still returns object' );

#!/usr/bin/perl -w

###############################################################################
#
# Tests for OLE::Storage_Lite PPS object creation and manipulation.
#
# Tests the PPS::Root, PPS::Dir, and PPS::File classes.
#
use strict;
use Test::More tests => 34;
use OLE::Storage_Lite;

# Test PPS::File creation.
{
    my $file_name = OLE::Storage_Lite::Asc2Ucs( 'TestFile' );
    my $file_data = 'Hello, World!';
    my $pps_file  = OLE::Storage_Lite::PPS::File->new( $file_name, $file_data );

    isa_ok( $pps_file, 'OLE::Storage_Lite::PPS::File',
        'PPS::File constructor' );

    isa_ok( $pps_file, 'OLE::Storage_Lite::PPS',
        'PPS::File inherits from PPS' );

    is( $pps_file->{Name}, $file_name, 'PPS::File has correct name' );
    is( $pps_file->{Data}, $file_data, 'PPS::File has correct data' );
    is( $pps_file->{Type}, 2,          'PPS::File has correct type' );

    is(
        $pps_file->_DataLen(),
        length( $file_data ),
        'PPS::File _DataLen works correctly'
    );
}

# Test PPS::File with empty data.
{
    my $file_name = OLE::Storage_Lite::Asc2Ucs( 'EmptyFile' );
    my $pps_file = OLE::Storage_Lite::PPS::File->new( $file_name, '' );

    isa_ok(
        $pps_file,
        'OLE::Storage_Lite::PPS::File',
        'PPS::File with empty data'
    );

    is( $pps_file->{Data},     '', 'Empty file has empty data' );
    is( $pps_file->_DataLen(), 0,  'Empty file has zero length' );
}

# Test PPS::Dir creation.
{
    my $dir_name = OLE::Storage_Lite::Asc2Ucs( 'TestDirectory' );
    my @time1 = ( 0, 0, 0, 1, 0, 100 );    # Jan 1, 2000.
    my @time2 = ( 0, 0, 0, 2, 0, 100 );    # Jan 2, 2000.
    my @children = ();

    my $pps_dir = OLE::Storage_Lite::PPS::Dir->new( $dir_name, \@time1, \@time2,
        \@children );

    isa_ok( $pps_dir, 'OLE::Storage_Lite::PPS::Dir', 'PPS::Dir constructor' );
    isa_ok( $pps_dir, 'OLE::Storage_Lite::PPS', 'PPS::Dir inherits from PPS' );

    is( $pps_dir->{Name}, $dir_name, 'PPS::Dir has correct name' );
    is( $pps_dir->{Type}, 1,         'PPS::Dir has correct type' );

    is_deeply( $pps_dir->{Time1st}, \@time1,
        'PPS::Dir has correct first timestamp' );

    is_deeply( $pps_dir->{Time2nd}, \@time2,
        'PPS::Dir has correct second timestamp' );

    is_deeply( $pps_dir->{Child}, \@children, 'PPS::Dir has correct children' );
}

# Test PPS::Root creation.
{
    my @time1 = ( 0, 0, 0, 1, 0, 100 );
    my @time2 = ( 0, 0, 0, 2, 0, 100 );
    my @children = ();

    my $pps_root =
      OLE::Storage_Lite::PPS::Root->new( \@time1, \@time2, \@children );

    isa_ok( $pps_root, 'OLE::Storage_Lite::PPS::Root',
        'PPS::Root constructor' );

    isa_ok( $pps_root, 'OLE::Storage_Lite::PPS',
        'PPS::Root inherits from PPS' );

    is( $pps_root->{Type}, 5, 'PPS::Root has correct type' );

    is_deeply( $pps_root->{Time1st}, \@time1,
        'PPS::Root has correct first timestamp' );

    is_deeply( $pps_root->{Time2nd}, \@time2,
        'PPS::Root has correct second timestamp' );

    is_deeply( $pps_root->{Child}, \@children,
        'PPS::Root has correct children' );
}

# Test PPS::File append method.
{
    my $file_name    = OLE::Storage_Lite::Asc2Ucs( 'AppendTest' );
    my $initial_data = 'Initial';

    my $pps_file =
      OLE::Storage_Lite::PPS::File->new( $file_name, $initial_data );

    $pps_file->append( ' Data' );
    is( $pps_file->{Data}, 'Initial Data', 'append() method works correctly' );
    is( $pps_file->_DataLen(), 12, 'append() updates data length correctly' );

    $pps_file->append( '!' );
    is( $pps_file->{Data}, 'Initial Data!', 'Multiple append() calls work' );
    is( $pps_file->_DataLen(), 13,
        'Multiple append() updates length correctly' );
}

# Test complex PPS tree structure.
{
    my @time1 = ( 0, 0, 0, 1, 0, 100 );
    my @time2 = ( 0, 0, 0, 2, 0, 100 );

    # Create files.
    my $file1 =
      OLE::Storage_Lite::PPS::File->new( OLE::Storage_Lite::Asc2Ucs( 'File1' ),
        'File 1 content' );
    my $file2 =
      OLE::Storage_Lite::PPS::File->new( OLE::Storage_Lite::Asc2Ucs( 'File2' ),
        'File 2 content' );

    # Create directory with files.
    my $dir = OLE::Storage_Lite::PPS::Dir->new(
        OLE::Storage_Lite::Asc2Ucs( 'Directory1' ),
        \@time1, \@time2, [ $file1, $file2 ] );

    # Create root with directory.
    my $root = OLE::Storage_Lite::PPS::Root->new( \@time1, \@time2, [$dir] );

    # Verify structure.
    is( scalar @{ $root->{Child} }, 1, 'Root has one child' );
    isa_ok( $root->{Child}->[0],
        'OLE::Storage_Lite::PPS::Dir', 'Root child is directory' );

    my $child_dir = $root->{Child}->[0];
    is( scalar @{ $child_dir->{Child} }, 2, 'Directory has two children' );

    isa_ok(
        $child_dir->{Child}->[0],
        'OLE::Storage_Lite::PPS::File',
        'Directory child 1 is file'
    );

    isa_ok(
        $child_dir->{Child}->[1],
        'OLE::Storage_Lite::PPS::File',
        'Directory child 2 is file'
    );
}

# Test PPS generic constructor.
{
    my $name = OLE::Storage_Lite::Asc2Ucs( 'GenericTest' );
    my $data = 'Test data';

    # Test FILE type.
    my $file_pps =
      OLE::Storage_Lite::PPS->new( 1, $name, 2, 0xFFFFFFFF, 0xFFFFFFFF,
        0xFFFFFFFF, undef, undef, 0, length( $data ),
        $data, undef );

    isa_ok(
        $file_pps,
        'OLE::Storage_Lite::PPS::File',
        'Generic constructor creates File for type 2'
    );

    # Test DIR type.
    my $dir_pps =
      OLE::Storage_Lite::PPS->new( 2, $name, 1, 0xFFFFFFFF, 0xFFFFFFFF,
        0xFFFFFFFF, undef, undef, 0, 0, undef, [] );

    isa_ok( $dir_pps, 'OLE::Storage_Lite::PPS::Dir',
        'Generic constructor creates Dir for type 1' );

    # Test ROOT type.
    my $root_pps =
      OLE::Storage_Lite::PPS->new( 0, $name, 5, 0xFFFFFFFF, 0xFFFFFFFF,
        0xFFFFFFFF, undef, undef, 0, 0, undef, [] );

    isa_ok(
        $root_pps,
        'OLE::Storage_Lite::PPS::Root',
        'Generic constructor creates Root for type 5'
    );
}

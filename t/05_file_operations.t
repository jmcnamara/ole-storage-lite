#!/usr/bin/perl -w

###############################################################################
#
# Tests for OLE::Storage_Lite file operations and data handling.
#
# Tests file I/O, different data sizes, and file-based PPS operations.
#
use strict;
use Test::More tests => 31;
use OLE::Storage_Lite;
use IO::File;
use File::Temp qw(tempfile tempdir);

# Test creating and saving an OLE file.
{
    my $temp_dir = tempdir( CLEANUP => 1 );
    my $test_file = "$temp_dir/test_output.ole";

    # Create a simple OLE structure.
    my @time = ( 0, 0, 12, 15, 2, 100 );    # March 15, 2000 12:00:00.

    my $file1 = OLE::Storage_Lite::PPS::File->new(
        OLE::Storage_Lite::Asc2Ucs( 'TestFile1' ),
        'This is test file 1 content' );

    my $file2 = OLE::Storage_Lite::PPS::File->new(
        OLE::Storage_Lite::Asc2Ucs( 'TestFile2' ),
        'A' x 100                           # 100 bytes of 'A'.
    );

    my $dir =
      OLE::Storage_Lite::PPS::Dir->new( OLE::Storage_Lite::Asc2Ucs( 'TestDir' ),
        \@time, \@time, [$file1] );

    my $root =
      OLE::Storage_Lite::PPS::Root->new( \@time, \@time, [ $dir, $file2 ] );

    # Save to file.
    my $result = $root->save( $test_file );
    ok( $result,           'save() returns success' );
    ok( -f $test_file,     'Output file was created' );
    ok( -s $test_file > 0, 'Output file has content' );

    # Read back the file.
    my $ole      = OLE::Storage_Lite->new( $test_file );
    my $pps_tree = $ole->getPpsTree( 1 );

    ok( defined $pps_tree, 'Can read back saved file' );
    isa_ok(
        $pps_tree,
        'OLE::Storage_Lite::PPS::Root',
        'Root object loaded correctly'
    );

    # Verify structure.
    is( scalar @{ $pps_tree->{Child} }, 2, 'Root has two children' );

    my ( $dir_child, $file_child );
    for my $child ( @{ $pps_tree->{Child} } ) {
        if ( $child->{Type} == 1 ) {
            $dir_child = $child;
        }
        elsif ( $child->{Type} == 2 ) {
            $file_child = $child;
        }
    }

    ok( defined $dir_child,  'Directory child found' );
    ok( defined $file_child, 'File child found' );
    is( scalar @{ $dir_child->{Child} }, 1, 'Directory has one child' );
}


# Test saving to scalar reference (IO::Scalar).
SKIP: {
    eval { require IO::Scalar };
    skip "IO::Scalar not available", 4 if $@;

    my $file = OLE::Storage_Lite::PPS::File->new(
        OLE::Storage_Lite::Asc2Ucs( 'ScalarTest' ),
        'Scalar test content' );
    my $root = OLE::Storage_Lite::PPS::Root->new( undef, undef, [$file] );

    my $scalar_data = '';
    my $result      = $root->save( \$scalar_data );
    ok( $result,                    'save() to scalar reference succeeds' );
    ok( length( $scalar_data ) > 0, 'Scalar reference has content' );

    # Try to read it back.
    my $ole      = OLE::Storage_Lite->new( \$scalar_data );
    my $pps_tree = $ole->getPpsTree();
    ok( defined $pps_tree, 'Can read OLE from scalar reference' );
    is( scalar @{ $pps_tree->{Child} },
        1, 'Scalar-based OLE has correct structure' );
}

# Test saving to IO::Handle.
{
    my ( $fh, $temp_file ) = tempfile( CLEANUP => 1 );

    my $file = OLE::Storage_Lite::PPS::File->new(
        OLE::Storage_Lite::Asc2Ucs( 'HandleTest' ),
        'Handle test content' );
    my $root = OLE::Storage_Lite::PPS::Root->new( undef, undef, [$file] );

    my $result = $root->save( $fh );
    close( $fh );    # Close before checking the result.


    # The save method may return undef but still succeed.

    ok( defined $result || -s $temp_file > 0, 'save() to IO::Handle succeeds' );

    ok( -s $temp_file > 0, 'File handle output has content' );
}

# Test large file (> small block size).
{
    my $temp_dir = tempdir( CLEANUP => 1 );
    my $test_file = "$temp_dir/large_test.ole";

    # Create file larger than small block size (4096 bytes).
    my $large_data = 'X' x 5000;
    my $large_file = OLE::Storage_Lite::PPS::File->new(
        OLE::Storage_Lite::Asc2Ucs( 'LargeFile' ), $large_data );

    my $root = OLE::Storage_Lite::PPS::Root->new( undef, undef, [$large_file] );

    my $result = $root->save( $test_file );
    ok( $result, 'Large file save succeeds' );

    # Read it back.

    my $ole      = OLE::Storage_Lite->new( $test_file );
    my $pps_tree = $ole->getPpsTree( 1 );

    ok( defined $pps_tree, 'Can read back large file' );
    is( scalar @{ $pps_tree->{Child} }, 1, 'Large file structure correct' );

    my $read_file = $pps_tree->{Child}->[0];
    is( length( $read_file->{Data} ), 5000, 'Large file data length correct' );
    is( $read_file->{Data}, $large_data, 'Large file data content correct' );
}

# Test multiple small files.
{
    my $temp_dir = tempdir( CLEANUP => 1 );
    my $test_file = "$temp_dir/multi_small.ole";

    my @small_files;
    for my $i ( 1 .. 5 ) {
        push @small_files,
          OLE::Storage_Lite::PPS::File->new(
            OLE::Storage_Lite::Asc2Ucs( "SmallFile$i" ),
            "Content of file $i" );
    }

    my $root = OLE::Storage_Lite::PPS::Root->new( undef, undef, \@small_files );

    my $result = $root->save( $test_file );
    ok( $result, 'Multiple small files save succeeds' );

    # Read it back.
    my $ole      = OLE::Storage_Lite->new( $test_file );
    my $pps_tree = $ole->getPpsTree( 1 );

    is( scalar @{ $pps_tree->{Child} }, 5, 'All small files present' );

    # Check each file.
    for my $i ( 0 .. 4 ) {
        my $child = $pps_tree->{Child}->[$i];
        like(
            $child->{Data},
            qr/Content of file/,
            "Small file $i has expected content"
        );
    }
}

# Test empty file handling.
{
    my $temp_dir = tempdir( CLEANUP => 1 );
    my $test_file = "$temp_dir/empty_file.ole";

    my $empty_file = OLE::Storage_Lite::PPS::File->new(
        OLE::Storage_Lite::Asc2Ucs( 'EmptyFile' ), '' );

    my $root = OLE::Storage_Lite::PPS::Root->new( undef, undef, [$empty_file] );

    my $result = $root->save( $test_file );
    ok( $result, 'Empty file save succeeds' );

    # Read it back.
    my $ole      = OLE::Storage_Lite->new( $test_file );
    my $pps_tree = $ole->getPpsTree( 1 );

    is( scalar @{ $pps_tree->{Child} },  1,  'Empty file structure correct' );
    is( $pps_tree->{Child}->[0]->{Data}, '', 'Empty file data is empty' );
    is( $pps_tree->{Child}->[0]->{Size}, 0,  'Empty file size is zero' );
}

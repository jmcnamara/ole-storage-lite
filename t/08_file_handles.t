#!/usr/bin/perl -w

###############################################################################
#
# Tests for OLE::Storage_Lite::PPS::File with file handles and newFile method.
#
# Tests the newFile constructor and file handle operations.
#
use strict;
use Test::More tests => 22;
use OLE::Storage_Lite;
use IO::File;
use File::Temp qw(tempfile tempdir);

# Test 1: newFile with temporary file (undef parameter)
{
    my $pps_file = OLE::Storage_Lite::PPS::File->newFile(
        OLE::Storage_Lite::Asc2Ucs( 'TempFile' ) );

    isa_ok(
        $pps_file,
        'OLE::Storage_Lite::PPS::File',
        'newFile with undef creates PPS::File'
    );
    ok( defined $pps_file->{_PPS_FILE}, 'newFile creates file handle' );
    isa_ok( $pps_file->{_PPS_FILE},
        'IO::File', 'File handle is IO::File object' );

    # Test appending to the file handle.

    $pps_file->append( 'Hello, ' );
    $pps_file->append( 'World!' );

    # Check data length.

    is( $pps_file->_DataLen(), 13,
        'File handle data length correct after append' );
}

# Test 2: newFile with empty string (should create temp file)
{
    my $pps_file = OLE::Storage_Lite::PPS::File->newFile(
        OLE::Storage_Lite::Asc2Ucs( 'EmptyStringFile' ), '' );

    isa_ok(
        $pps_file,
        'OLE::Storage_Lite::PPS::File',
        'newFile with empty string creates PPS::File'
    );
    ok( defined $pps_file->{_PPS_FILE},
        'newFile with empty string creates file handle' );
}

# Test 3: newFile with actual file name.
{
    my ( $fh, $temp_file ) = tempfile( CLEANUP => 1 );
    print $fh "Initial content";
    close $fh;

    my $pps_file = OLE::Storage_Lite::PPS::File->newFile(
        OLE::Storage_Lite::Asc2Ucs( 'RealFile' ), $temp_file );

    isa_ok(
        $pps_file,
        'OLE::Storage_Lite::PPS::File',
        'newFile with filename creates PPS::File'
    );
    ok( defined $pps_file->{_PPS_FILE},
        'newFile with filename creates file handle' );

    # Check initial data length.

    is( $pps_file->_DataLen(), 15, 'Initial file content length correct' );

    # Test appending.

    $pps_file->append( ' - appended' );
    is( $pps_file->_DataLen(), 26, 'File length after append correct' );
}

# Test 4: newFile with IO::Handle object.
{
    my ( $fh, $temp_file ) = tempfile( CLEANUP => 1 );
    print $fh "Handle content";
    close( $fh );

    # Reopen for reading and writing.

    my $rw_fh = IO::File->new( $temp_file, 'r+' )
      or die "Cannot reopen file: $!";
    $rw_fh->seek( 0, 2 );    # Seek to end for appending.


    my $pps_file = OLE::Storage_Lite::PPS::File->newFile(
        OLE::Storage_Lite::Asc2Ucs( 'HandleFile' ), $rw_fh );

    isa_ok(
        $pps_file,
        'OLE::Storage_Lite::PPS::File',
        'newFile with IO::Handle creates PPS::File'
    );
    is( $pps_file->{_PPS_FILE}, $rw_fh, 'newFile uses provided file handle' );

    # Test appending to the handle.
    $pps_file->append( ' - more' );

    # The file already had "Handle content" (14 chars) plus " - more"
    # (7 chars) = 21 chars.
    is( $pps_file->_DataLen(), 21, 'Handle-based file length correct' );

    $rw_fh->close();
}

# Test 5: newFile with non-existent file (should fail)
{
    my $pps_file = OLE::Storage_Lite::PPS::File->newFile(
        OLE::Storage_Lite::Asc2Ucs( 'BadFile' ),
        '/nonexistent/path/file.txt' );

    is( $pps_file, undef, 'newFile with non-existent file returns undef' );
}

# Test 6: newFile with invalid reference type (should fail)
{
    my $invalid_ref = {};
    my $pps_file    = OLE::Storage_Lite::PPS::File->newFile(
        OLE::Storage_Lite::Asc2Ucs( 'InvalidRef' ), $invalid_ref );

    is( $pps_file, undef, 'newFile with invalid reference returns undef' );
}

# Test 7: Compare regular PPS::File vs newFile behavior.
{
    my $regular_file = OLE::Storage_Lite::PPS::File->new(
        OLE::Storage_Lite::Asc2Ucs( 'Regular' ),
        'Regular content' );

    my $newfile_based = OLE::Storage_Lite::PPS::File->newFile(
        OLE::Storage_Lite::Asc2Ucs( 'NewFile' ) );
    $newfile_based->append( 'NewFile content' );

    # Both should behave similarly for data operations.

    ok( !defined $regular_file->{_PPS_FILE},
        'Regular file has no file handle' );
    ok( defined $newfile_based->{_PPS_FILE}, 'newFile-based has file handle' );

    is( $regular_file->_DataLen(),  15, 'Regular file data length correct' );
    is( $newfile_based->_DataLen(), 15, 'newFile-based data length correct' );
}

# Test 8: Test file handle autoflush and binmode.
{
    my $pps_file = OLE::Storage_Lite::PPS::File->newFile(
        OLE::Storage_Lite::Asc2Ucs( 'AutoflushTest' ) );

    # File handle should be created with autoflush and binmode.
    ok( defined $pps_file->{_PPS_FILE}, 'File handle created' );

    # Test that we can write and the handle behaves correctly.
    $pps_file->append( "Line 1\n" );
    $pps_file->append( "Line 2\n" );

    is( $pps_file->_DataLen(), 14, 'Multi-line append works correctly' );
}

# Test 9: Integration test - save and load file with file handles.
my $temp_dir = tempdir( CLEANUP => 1 );
my $output_file = "$temp_dir/integrated_test.ole";

# Create a PPS structure with both regular and file-handle based files.
my $regular_file = OLE::Storage_Lite::PPS::File->new(
    OLE::Storage_Lite::Asc2Ucs( 'RegularFile' ),
    'Regular data' );

my $handle_file = OLE::Storage_Lite::PPS::File->newFile(
    OLE::Storage_Lite::Asc2Ucs( 'HandleFile' ) );
$handle_file->append( 'Handle data' );

my $root =
  OLE::Storage_Lite::PPS::Root->new( undef, undef,
    [ $regular_file, $handle_file ] );

# Save and reload.
my $save_result = $root->save( $output_file );
if ( $save_result && -f $output_file ) {
    my $ole      = OLE::Storage_Lite->new( $output_file );
    my $pps_tree = $ole->getPpsTree( 1 );

    is( scalar @{ $pps_tree->{Child} },
        2, 'Both file types saved and loaded correctly' );
}
else {
    ok( 0, 'Both file types saved and loaded correctly' );
}

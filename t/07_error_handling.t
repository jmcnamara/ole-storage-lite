#!/usr/bin/perl -w

###############################################################################
#
# Tests for OLE::Storage_Lite error handling and edge cases.
#
# Tests error conditions, malformed inputs, and boundary conditions.
#

use strict;
use Test::More tests => 18;
use OLE::Storage_Lite;
use File::Temp qw(tempdir tempfile);

# Test 1: Non-existent file handling.
{
    my $ole      = OLE::Storage_Lite->new( 'nonexistent_file.xls' );
    my $pps_tree = $ole->getPpsTree();

    is( $pps_tree, undef, 'getPpsTree returns undef for non-existent file' );

    my @search_results =
      $ole->getPpsSearch( [ OLE::Storage_Lite::Asc2Ucs( 'anything' ) ] );

    # When file doesn't exist, search may return undef in the array.
    my @real_results = grep { defined $_ } @search_results;
    is( scalar @real_results, 0, 'Search on non-existent file returns empty' );

    my $nth_pps = $ole->getNthPps( 0 );
    is( $nth_pps, undef, 'getNthPps returns undef for non-existent file' );
}

# Test 2: Invalid file content (not an OLE file)
{
    my ( $fh, $temp_file ) = tempfile( CLEANUP => 1 );
    print $fh "This is not an OLE file\n" x 100;
    close $fh;

    my $ole      = OLE::Storage_Lite->new( $temp_file );
    my $pps_tree = $ole->getPpsTree();

    is( $pps_tree, undef, 'getPpsTree returns undef for invalid OLE file' );
}

# Test 3: Empty file.
{
    my ( $fh, $temp_file ) = tempfile( CLEANUP => 1 );
    close $fh;    # Create empty file.


    my $ole      = OLE::Storage_Lite->new( $temp_file );
    my $pps_tree = $ole->getPpsTree();

    is( $pps_tree, undef, 'getPpsTree returns undef for empty file' );
}

# Test 4: Invalid PPS type in constructor.
{
    eval {
        my $invalid_pps =
          OLE::Storage_Lite::PPS->new( 0, 'Test', 99, 0, 0, 0, undef, undef, 0,
            0, undef, undef );
    };
    like( $@, qr/Error PPS/, 'Invalid PPS type throws error' );
}

# Test 5: Save with invalid parameters.
{
    my $root = OLE::Storage_Lite::PPS::Root->new();

    # Try to save to invalid location.

    my $result = $root->save( '/root/invalid_path/test.ole' )
      ;    # Should fail due to permissions.

    is( $result, undef, 'Save to invalid path returns undef' );
}

# Test 6: Very long filename handling.
{
    # Create a filename that's longer than typical limits.

    my $long_name    = 'A' x 200;
    my $unicode_name = OLE::Storage_Lite::Asc2Ucs( $long_name );

    my $file = OLE::Storage_Lite::PPS::File->new( $unicode_name, 'test' );
    isa_ok(
        $file,
        'OLE::Storage_Lite::PPS::File',
        'Very long filename file creation succeeds'
    );

    # The actual name might be truncated during save/load.

    ok( length( $file->{Name} ) > 0, 'Long filename PPS has non-empty name' );
}

# Test 7: Null and special characters in names.
{
    my $special_name = "Test\x00\xFF\x01Special";
    my $unicode_name = OLE::Storage_Lite::Asc2Ucs( $special_name );

    my $file = OLE::Storage_Lite::PPS::File->new( $unicode_name, 'test' );
    isa_ok(
        $file,
        'OLE::Storage_Lite::PPS::File',
        'Special characters in filename work'
    );
}


# Test 8: Deep directory nesting.
{
    my @time = ( 0, 0, 12, 15, 2, 100 );
    my $file = OLE::Storage_Lite::PPS::File->new(
        OLE::Storage_Lite::Asc2Ucs( 'DeepFile' ),
        'deep content' );

    # Create nested structure: Root -> Dir1 -> Dir2 -> Dir3 -> File.

    my $dir3 =
      OLE::Storage_Lite::PPS::Dir->new( OLE::Storage_Lite::Asc2Ucs( 'Dir3' ),
        \@time, \@time, [$file] );

    my $dir2 =
      OLE::Storage_Lite::PPS::Dir->new( OLE::Storage_Lite::Asc2Ucs( 'Dir2' ),
        \@time, \@time, [$dir3] );

    my $dir1 =
      OLE::Storage_Lite::PPS::Dir->new( OLE::Storage_Lite::Asc2Ucs( 'Dir1' ),
        \@time, \@time, [$dir2] );

    my $root = OLE::Storage_Lite::PPS::Root->new( \@time, \@time, [$dir1] );

    # Try to save and load.
    my $temp_dir = tempdir( CLEANUP => 1 );
    my $test_file = "$temp_dir/deep_test.ole";

    my $save_result = $root->save( $test_file );
    ok( $save_result, 'Deep directory structure saves successfully' );

    if ( $save_result && -f $test_file ) {
        my $ole      = OLE::Storage_Lite->new( $test_file );
        my $pps_tree = $ole->getPpsTree();

        ok( defined $pps_tree, 'Deep directory structure loads successfully' );

        # Navigate to the deep file.

        my $current = $pps_tree;
        for my $level ( 1 .. 3 ) {
            ok( defined $current->{Child}, "Level $level has children" );
            $current = $current->{Child}->[0];
        }
    }
    else {
        # If save failed, skip the load tests.
        ok( 0, 'Deep directory structure loads successfully' ) for 1 .. 4;
    }
}

# Test 9: Unicode string conversion edge cases.
{
    # Test with null string.
    my $null_unicode = OLE::Storage_Lite::Asc2Ucs( '' );
    is( $null_unicode, "\x00", 'Empty string converts to single null' );

    my $back_to_null = OLE::Storage_Lite::Ucs2Asc( $null_unicode );
    is( length( $back_to_null ), 0, 'Null Unicode converts back correctly' );

    # Test with already null-terminated string.
    my $null_term         = "Test\x00";
    my $unicode_null_term = OLE::Storage_Lite::Asc2Ucs( $null_term );
    my $back_to_ascii     = OLE::Storage_Lite::Ucs2Asc( $unicode_null_term );

    like( $back_to_ascii, qr/Test/,
        'Null-terminated string survives round-trip' );
}

#!/usr/bin/perl -w

###############################################################################
#
# Tests for OLE::Storage_Lite search functionality.
#
# Tests getPpsSearch method with various search criteria.
#

use strict;
use Test::More tests => 16;
use OLE::Storage_Lite;
use File::Temp qw(tempdir);

# Create a test OLE file with multiple entries for searching.
my $temp_dir = tempdir( CLEANUP => 1 );
my $test_file = "$temp_dir/search_test.ole";

# Create test structure.
my @time = ( 0, 0, 12, 15, 2, 100 );

my $file1 =
  OLE::Storage_Lite::PPS::File->new( OLE::Storage_Lite::Asc2Ucs( 'TestFile' ),
    'Test file content' );

my $file2 = OLE::Storage_Lite::PPS::File->new(
    OLE::Storage_Lite::Asc2Ucs( 'AnotherFile' ),
    'Another file content' );

my $file3 = OLE::Storage_Lite::PPS::File->new(
    OLE::Storage_Lite::Asc2Ucs( 'testfile' ),    # lowercase version.

    'Lowercase test file'
);

my $dir1 = OLE::Storage_Lite::PPS::Dir->new(
    OLE::Storage_Lite::Asc2Ucs( 'TestDirectory' ),
    \@time, \@time, [$file2] );

my $dir2 =
  OLE::Storage_Lite::PPS::Dir->new( OLE::Storage_Lite::Asc2Ucs( 'SubDir' ),
    \@time, \@time, [] );

my $root =
  OLE::Storage_Lite::PPS::Root->new( \@time, \@time,
    [ $file1, $file3, $dir1, $dir2 ] );

# Save the test file.
$root->save( $test_file );

# Now test searching.
SKIP: {
    skip 'Test file creation failed', 15 unless -f $test_file;

    my $ole = OLE::Storage_Lite->new( $test_file );

    # Test 1: Search for single file by exact name.
    {
        my @results =
          $ole->getPpsSearch( [ OLE::Storage_Lite::Asc2Ucs( 'TestFile' ) ] );

        is( scalar @results, 1, 'Found one exact match for TestFile' );

        is(
            $results[0]->{Name},
            OLE::Storage_Lite::Asc2Ucs( 'TestFile' ),
            'Found correct file'
        );

        is( $results[0]->{Type}, 2, 'Found object is a file' );
    }

    # Test 2: Search for multiple files.
    {
        my @results = $ole->getPpsSearch(
            [
                OLE::Storage_Lite::Asc2Ucs( 'TestFile' ),
                OLE::Storage_Lite::Asc2Ucs( 'AnotherFile' )
            ]
        );

        is( scalar @results, 2, 'Found two files with multiple search terms' );

        my %found_names;
        for my $result ( @results ) {
            my $name = OLE::Storage_Lite::Ucs2Asc( $result->{Name} );
            $name =~ s/\x00//g;    # Remove null terminators.

            $found_names{$name} = 1;
        }

        ok( $found_names{'TestFile'}, 'TestFile found in multiple search' );
        ok( $found_names{'AnotherFile'},
            'AnotherFile found in multiple search' );
    }

    # Test 3: Search for directory.
    {
        my @results = $ole->getPpsSearch(
            [ OLE::Storage_Lite::Asc2Ucs( 'TestDirectory' ) ] );

        is( scalar @results,     1, 'Found directory by name' );
        is( $results[0]->{Type}, 1, 'Found object is a directory' );
    }

    # Test 4: Search with data retrieval.
    {
        # Get data.
        my @results =
          $ole->getPpsSearch( [ OLE::Storage_Lite::Asc2Ucs( 'TestFile' ) ], 1 );


        is( scalar @results, 1, 'Found file with data option' );
        ok( defined $results[0]->{Data},
            'Result includes data when requested' );
        is(
            $results[0]->{Data},
            'Test file content',
            'Data content is correct'
        );
    }

    # Test 5: Case-insensitive search.

    {
        # Case insensitive.
        my @results =
          $ole->getPpsSearch( [ OLE::Storage_Lite::Asc2Ucs( 'testfile' ) ], 0, 1 );

        is( scalar @results,
            2, 'Case-insensitive search finds both testfile and TestFile' );

        # Verify we got both the lowercase and uppercase versions.
        my %found_names;
        for my $result ( @results ) {
            my $name = OLE::Storage_Lite::Ucs2Asc( $result->{Name} );
            $name =~ s/\x00//g;
            $found_names{$name} = 1;
        }

        ok(
            $found_names{'testfile'} && $found_names{'TestFile'},
            'Case-insensitive search found both variants'
        );
    }

    # Test 6: Search for non-existent entry.
    {
        my @results = $ole->getPpsSearch(
            [ OLE::Storage_Lite::Asc2Ucs( 'NonExistentFile' ) ] );

        is( scalar @results,
            0, 'Search for non-existent file returns empty results' );
    }

    # Test 7: Search in subdirectory.
    {
        my @results =
          $ole->getPpsSearch( [ OLE::Storage_Lite::Asc2Ucs( 'AnotherFile' ) ] );

        is( scalar @results,     1, 'Found file within subdirectory' );
        is( $results[0]->{Type}, 2, 'File in subdirectory is correct type' );
    }
}

#!/usr/bin/perl -w

###############################################################################
#
# Tests for OLE::Storage_Lite Unicode/ASCII conversion utilities.
#
# Tests the Asc2Ucs and Ucs2Asc utility functions.
#
use strict;
use Test::More tests => 23;
use OLE::Storage_Lite;

# Test Asc2Ucs function.
{
    my $ascii   = 'Hello';
    my $unicode = OLE::Storage_Lite::Asc2Ucs( $ascii );

    # Check length - should be double (no null terminator automatically added).
    is( length( $unicode ), length( $ascii ) * 2, 'Asc2Ucs correct length' );

    # Check that every other byte is null.

    my @bytes = unpack( 'C*', $unicode );
    for my $i ( 1, 3, 5, 7, 9 ) {
        is( $bytes[$i], 0, "Byte $i is null in Unicode string" );
    }

    # Check the actual character bytes.

    is( $bytes[0], ord( 'H' ), 'First character H correct' );
    is( $bytes[2], ord( 'e' ), 'Second character e correct' );
    is( $bytes[4], ord( 'l' ), 'Third character l correct' );
    is( $bytes[6], ord( 'l' ), 'Fourth character l correct' );
    is( $bytes[8], ord( 'o' ), 'Fifth character o correct' );
}

# Test Ucs2Asc function.
{
    # Create a Unicode string manually.
    my $unicode = "H\x00e\x00l\x00l\x00o\x00";
    my $ascii   = OLE::Storage_Lite::Ucs2Asc( $unicode );

    is( $ascii,           "Hello", 'Ucs2Asc converts correctly' );
    is( length( $ascii ), 5,       'Ucs2Asc result has correct length' );
}

# Test round-trip conversion.
{
    my @test_strings = (
        'Hello',
        'World',
        'Test123',
        'A',
        '',    # Empty string.

        'Special!@#$%^&*()',
        'Root Entry',
    );

    for my $original ( @test_strings ) {
        my $unicode       = OLE::Storage_Lite::Asc2Ucs( $original );
        my $back_to_ascii = OLE::Storage_Lite::Ucs2Asc( $unicode );

        # Remove any null bytes for comparison.
        $back_to_ascii =~ s/\x00//g;

        is( $back_to_ascii, $original,
            "Round-trip conversion for '$original'" );
    }
}

# Test empty string conversion.
{
    my $empty_ascii   = '';
    my $empty_unicode = OLE::Storage_Lite::Asc2Ucs( $empty_ascii );
    is( $empty_unicode, "\x00", 'Empty string converts to single null' );

    my $back_to_empty = OLE::Storage_Lite::Ucs2Asc( $empty_unicode );
    is( $back_to_empty, "", 'Empty Unicode converts back correctly' );
}

# Test with actual Unicode input to Ucs2Asc.
{
    my $test_unicode =
      pack( 'v*', ( ord( 'T' ), ord( 'e' ), ord( 's' ), ord( 't' ) ) );
    my $result = OLE::Storage_Lite::Ucs2Asc( $test_unicode );
    is( $result, "Test", 'Ucs2Asc with packed Unicode data works correctly' );
}

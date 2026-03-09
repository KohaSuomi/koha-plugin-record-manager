#!/usr/bin/perl

# Copyright 2026 KohaSuomi
#
# This script removes test records created by populate_test_data.pl
# and any invalid records with corrupted MARC data

use Modern::Perl;
use Getopt::Long;
use C4::Context;
use Koha::Biblios;
use MARC::Record;

=head1 NAME

clear_test_data.pl - Remove test records created by populate_test_data.pl

=head1 SYNOPSIS

    perl clear_test_data.pl [options]

=head1 OPTIONS

=over 4

=item B<--dry-run>

Show what would be deleted without actually deleting

=item B<--verbose>

Print detailed output

=item B<--help>

Print this help message

=back

=head1 EXAMPLE

    # Preview what will be deleted
    perl clear_test_data.pl --dry-run --verbose

    # Actually delete the records
    perl clear_test_data.pl --verbose

=head1 DESCRIPTION

This script removes test records created by populate_test_data.pl by identifying
records with control numbers in the test ranges:
- Host records: 100001-100999 (001 field contains 100xxx)
- Component parts: 200001-299999 (001 field is 200xxx-299xxx)
- Orphan records: 800001-899999 (001 field is 800xxx-899xxx)

It will also delete any records with invalid MARC data that cannot be decoded
(e.g., fields without subfields, malformed XML).

=cut

my $delete = 0;
my $verbose = 0;
my $help = 0;

GetOptions(
    'delete'   => \$delete,
    'verbose'  => \$verbose,
    'help'     => \$help,
) or die "Error in command line arguments\n";

if ($help) {
    print_help();
    exit 0;
}

print "=" x 70 . "\n";
print "Clear Test Data for Record Manager\n";
print "=" x 70 . "\n";
if (!$delete) {
    print "DRY RUN MODE - No records will be deleted\n";
    print "=" x 70 . "\n";
}
print "\n";

my $dbh = C4::Context->dbh;

# Find all biblionumbers
my $query = q{
    SELECT biblionumber 
    FROM biblio 
    ORDER BY biblionumber
};

my $sth = $dbh->prepare($query);
$sth->execute();

my @records_to_delete;
my $host_count = 0;
my $component_count = 0;
my $orphan_count = 0;
my $invalid_count = 0;
my $checked_count = 0;

print "Scanning records...\n" if $verbose;

while (my ($biblionumber) = $sth->fetchrow_array) {
    $checked_count++;
    
    my $biblio = Koha::Biblios->find($biblionumber);
    next unless $biblio;
    
    my $marc;
    my $is_invalid = 0;
    
    # Try to get the MARC record, catch decoding errors
    eval {
        $marc = $biblio->metadata->record;
    };
    
    if ($@) {
        # Record has invalid metadata that can't be decoded
        $is_invalid = 1;
        $invalid_count++;
        
        push @records_to_delete, {
            biblionumber => $biblionumber,
            control_number => 'invalid',
            type => 'invalid',
            title => 'Invalid MARC record',
        };
        
        if ($verbose) {
            my $error = $@;
            $error =~ s/\n/ /g;
            print sprintf("  Found invalid [%d]: Cannot decode metadata - %s\n", 
                $biblionumber,
                substr($error, 0, 80)
            );
        }
        next;
    }
    
    next unless $marc;
    
    my $field_001 = $marc->field('001');
    next unless $field_001;
    
    my $control_number = $field_001->data();
    next unless $control_number;
    
    # Remove any prefix like (FI-MELINDA) from 001
    $control_number =~ s/^\([^)]+\)//;
    $control_number =~ s/^\s+//;
    
    my $is_test_record = 0;
    my $record_type = '';
    
    # Check if it's a host record (100xxx pattern in 001)
    if ($control_number =~ /^10[0-9]{4,}$/) {
        $is_test_record = 1;
        $record_type = 'host';
        $host_count++;
    }
    # Check if it's a component part (200xxx-299xxx)
    elsif ($control_number =~ /^2[0-9]{5,}$/) {
        $is_test_record = 1;
        $record_type = 'component';
        $component_count++;
    }
    # Check if it's an orphan record (800xxx-899xxx)
    elsif ($control_number =~ /^8[0-9]{5,}$/) {
        $is_test_record = 1;
        $record_type = 'orphan';
        $orphan_count++;
    }
    
    if ($is_test_record) {
        my $title_field = $marc->field('245');
        my $title = $title_field ? $title_field->subfield('a') : 'No title';
        
        push @records_to_delete, {
            biblionumber => $biblionumber,
            control_number => $control_number,
            type => $record_type,
            title => $title,
        };
        
        if ($verbose) {
            print sprintf("  Found %s [%d]: %s (001: %s)\n", 
                $record_type, 
                $biblionumber, 
                $title, 
                $control_number
            );
        }
    }
}

print "\n";
print "=" x 70 . "\n";
print "Scan Complete\n";
print "=" x 70 . "\n";
print "Records checked:        $checked_count\n";
print "Host records found:     $host_count\n";
print "Component parts found:  $component_count\n";
print "Orphan records found:   $orphan_count\n";
print "Invalid records found:  $invalid_count\n";
print "Total to delete:        " . scalar(@records_to_delete) . "\n";
print "=" x 70 . "\n\n";

if (@records_to_delete == 0) {
    print "No test records found to delete.\n";
    exit 0;
}

if (!$delete) {
    print "DRY RUN: Would delete " . scalar(@records_to_delete) . " records.\n";
    print "Run with --delete to actually delete these records.\n";
    exit 0;
}

print "Deleting records...\n";

my $deleted_count = 0;
my $failed_count = 0;
my @failed_records;

foreach my $record (@records_to_delete) {
    my $biblionumber = $record->{biblionumber};
    
    eval {
        my $biblio = Koha::Biblios->find($biblionumber);
        
        if (!$biblio) {
            $failed_count++;
            push @failed_records, {
                %$record,
                error => "Biblio not found",
            };
            if ($verbose) {
                print "  FAILED to delete [$biblionumber]: Biblio not found\n";
            }
        } else {
            $biblio->delete;
            $deleted_count++;
            if ($verbose) {
                print "  Deleted $record->{type} [$biblionumber]: $record->{title}\n";
            }
        }
    };
    
    if ($@) {
        $failed_count++;
        push @failed_records, {
            %$record,
            error => $@,
        };
        if ($verbose) {
            print "  ERROR deleting [$biblionumber]: $@\n";
        }
    }
}

print "\n";
print "=" x 70 . "\n";
print "Deletion Complete\n";
print "=" x 70 . "\n";
print "Successfully deleted:   $deleted_count\n";
print "Failed to delete:       $failed_count\n";
print "=" x 70 . "\n";

if (@failed_records) {
    print "\nFailed Records:\n";
    print "-" x 70 . "\n";
    foreach my $record (@failed_records) {
        print sprintf("  [%d] %s - %s\n", 
            $record->{biblionumber}, 
            $record->{title}, 
            $record->{error}
        );
    }
    print "\n";
}

print "\nDone!\n";

sub print_help {
    print <<'HELP';
clear_test_data.pl - Remove test records created by populate_test_data.pl

SYNOPSIS:
    perl clear_test_data.pl [options]

OPTIONS:
    --delete    Actually delete the records
    --verbose   Print detailed output
    --help      Show this help message

EXAMPLES:
    # Preview what will be deleted
    perl clear_test_data.pl --verbose

    # Actually delete the records
    perl clear_test_data.pl --delete --verbose

    # Quick deletion without verbose output
    perl clear_test_data.pl --delete

DESCRIPTION:
    This script removes test records created by populate_test_data.pl.
    
    It identifies test records by their control numbers (001 field):
    
    - Host records: 100001-100999
      - Control numbers starting with 100xxx
      - May include prefix like (FI-MELINDA)100001
    
    - Component Parts: 200001-299999
      - Control numbers 200xxx-299xxx
    
    - Orphan Records: 800001-899999
      - Control numbers 800xxx-899xxx
    
    - Invalid Records: Records with corrupted MARC data
      - E.g., fields without subfields, malformed XML
      - These will also be deleted
    
    The script will:
    1. Scan all records in the database
    2. Identify test records by control number pattern
    3. Identify invalid records that can't be decoded
    4. Delete them using Koha::Biblios->delete
    5. Report success/failure for each deletion
    
    Use --delete to actually delete the records. Without this option, the script will only
    preview what will be deleted.

HELP
}

1;

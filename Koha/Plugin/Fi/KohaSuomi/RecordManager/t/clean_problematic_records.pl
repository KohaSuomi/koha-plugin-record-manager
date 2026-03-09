#!/usr/bin/perl

# Clean up problematic biblio records that have no metadata

use Modern::Perl;
use C4::Context;
use C4::Biblio;
use Koha::Biblios;
use Getopt::Long;

my $dry_run = 1;
my $fix = 0;
my $delete = 0;

GetOptions(
    'dry-run!' => \$dry_run,
    'fix'      => \$fix,
    'delete'   => \$delete,
) or die "Error in command line arguments\n";

if ($fix || $delete) {
    $dry_run = 0;
}

print "=" x 70 . "\n";
print "Biblio Metadata Checker\n";
print "=" x 70 . "\n";
if ($dry_run) {
    print "Mode: DRY RUN (no changes will be made)\n";
    print "Use --fix to actually fix records, or --delete to remove them\n";
} elsif ($delete) {
    print "Mode: DELETE problematic records\n";
} else {
    print "Mode: FIX problematic records\n";
}
print "=" x 70 . "\n\n";

my $dbh = C4::Context->dbh;

# Check for biblios without metadata
print "Checking for biblios without metadata...\n";
my $query = q{
    SELECT b.biblionumber, b.title
    FROM biblio b
    LEFT JOIN biblio_metadata bm ON b.biblionumber = bm.biblionumber
    WHERE bm.biblionumber IS NULL
};

my $sth = $dbh->prepare($query);
$sth->execute();

my @problematic;
while (my $row = $sth->fetchrow_hashref) {
    push @problematic, $row;
}

if (@problematic == 0) {
    print "✓ No problematic records found!\n";
    print "All biblios have proper metadata.\n\n";
    exit 0;
}

print "Found " . scalar(@problematic) . " biblio(s) without metadata:\n\n";

foreach my $biblio (@problematic) {
    print "  Biblionumber: $biblio->{biblionumber}\n";
    print "  Title: " . ($biblio->{title} || 'N/A') . "\n";
    
    if (!$dry_run) {
        if ($delete) {
            print "  → DELETING record...\n";
            eval {
                C4::Biblio::DelBiblio($biblio->{biblionumber});
                print "  ✓ Deleted\n";
            };
            if ($@) {
                print "  ✗ Error deleting: $@\n";
            }
        } else {
            print "  → Cannot fix: Record has no MARC metadata to restore\n";
            print "     Consider deleting with --delete\n";
        }
    }
    print "\n";
}

print "=" x 70 . "\n";
print "Summary:\n";
print "=" x 70 . "\n";
print "Problematic records: " . scalar(@problematic) . "\n";

if ($dry_run) {
    print "\nTo remove these records, run:\n";
    print "  ./clean_problematic_records.pl --delete\n\n";
    print "⚠️  WARNING: This will permanently delete the records!\n";
}

1;

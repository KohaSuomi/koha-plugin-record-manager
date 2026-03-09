#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::RecordManager;
use Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records;

my $help;
GetOptions(
    'help|h' => \$help,
) or die "Error in command line arguments\n";

if ($help) {
    print "Usage: find_host_links.pl [--help|-h]\n";
    print "This script finds and processes host links in Koha records.\n";
    exit 0;
}

my $record_manager = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
my $results = $record_manager->get_orphan_records();

foreach my $record (@$results) {
    print "Orphan record found: " .$record->{'host-item'} . " " . $record->{title} . " " . $record->{id} . "\n";
    # Additional processing can be done here
}


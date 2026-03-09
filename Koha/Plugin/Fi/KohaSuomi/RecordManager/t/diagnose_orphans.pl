#!/usr/bin/perl

# Quick diagnostic script to check orphan detection is working

use Modern::Perl;
use C4::Context;
use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::RecordManager;
use Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records;
use Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search;
use Data::Dumper;

print "=" x 70 . "\n";
print "Orphan Detection Diagnostics\n";
print "=" x 70 . "\n\n";

# Test 1: Check if we can find component parts
print "1. Searching for component parts (records with 773 field)...\n";
my $search = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search->new({size => 10});
my ($scroll_id, $results, $total) = $search->search_component_parts();
print "   Found $total component part(s)\n";

if ($total > 0) {
    print "   First few component parts:\n";
    my $count = 0;
    foreach my $hit (@{$results->{hits}{hits}}) {
        last if ++$count > 3;
        my $component = $hit->{_source};
        my $w = $component->{'record-control-number-773w'}[0] || 'N/A';
        my $title = $component->{'title'}[0] || 'N/A';
        print "   - ID: $hit->{_id}, Title: $title, 773\$w: $w\n";
    }
}
print "\n";

# Test 2: Check orphan detection
print "2. Running orphan detection...\n";
my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
my $result = eval {
    $records->get_orphan_records({ page => 1, per_page => 20 });
};

if ($@) {
    print "   ERROR: $@\n";
} else {
    my $orphan_count = $result->{total};
    print "   Found $orphan_count orphan record(s)\n";
    
    if ($orphan_count > 0) {
        print "   Orphan records:\n";
        foreach my $orphan (@{$result->{orphans}}) {
            print "   - ID: $orphan->{id}\n";
            print "     Title: $orphan->{title}\n";
            print "     Missing host: $orphan->{cni_control_number}\n";
            print "\n";
        }
    }
}

print "\n";

# Test 3: Manual host check for known missing control number
print "3. Testing host_record_exists for control number 900001...\n";
my $exists = $records->host_record_exists('900001', '(FI-MELINDA)900001');
print "   Result: " . ($exists ? "EXISTS (should be 0 for orphan)" : "NOT FOUND (correct for orphan)") . "\n";

print "\n";
print "=" x 70 . "\n";
print "Diagnostics complete\n";
print "=" x 70 . "\n";

1;

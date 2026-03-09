#!/usr/bin/perl

# Comprehensive setup check for orphan detection

use Modern::Perl;
use C4::Context;
use C4::Biblio;
use Koha::Biblios;
use MARC::Record;
use Data::Dumper;

print "=" x 70 . "\n";
print "Setup Check for Orphan Detection\n";
print "=" x 70 . "\n\n";

# Check 1: Database records
print "1. Checking database for records with MARC 773 field...\n";

my $biblios = Koha::Biblios->search();
my $total_biblios = $biblios->count;
print "   Total biblios in database: $total_biblios\n";

if ($total_biblios == 0) {
    print "   ⚠️  NO RECORDS FOUND!\n";
    print "   Run populate_test_data.pl to create test data:\n";
    print "   ./populate_test_data.pl --hosts=10 --components=3 --orphans=5 --verbose\n\n";
} else {
    my @component_parts;
    my @orphan_candidates;
    my @host_records;
    my $skipped = 0;
    
    while (my $biblio = $biblios->next) {
        my $biblionumber = $biblio->biblionumber;
        my $marc = eval { C4::Biblio::GetMarcBiblio({ biblionumber => $biblionumber }) };
        if ($@) {
            $skipped++;
            next;
        }
        next unless $marc;
        
        # Check for 773 field (component parts)
        if (my $field773 = $marc->field('773')) {
            my $w = $field773->subfield('w') || '';
            my $title = '';
            if (my $field245 = $marc->field('245')) {
                $title = $field245->subfield('a') || '';
            }
            
            push @component_parts, {
                biblionumber => $biblionumber,
                title => $title,
                host_ref => $w,
            };
            
            # Check if it's an orphan (host control number 900000+)
            if ($w =~ /900\d{3,}/) {
                push @orphan_candidates, {
                    biblionumber => $biblionumber,
                    title => $title,
                    missing_host => $w,
                };
            }
        } else {
            # It's a host record (no 773)
            my $control_number = '';
            if (my $field001 = $marc->field('001')) {
                $control_number = $field001->data();
            }
            
            if ($control_number) {
                my $title = '';
                if (my $field245 = $marc->field('245')) {
                    $title = $field245->subfield('a') || '';
                }
                
                push @host_records, {
                    biblionumber => $biblionumber,
                    control_number => $control_number,
                    title => $title,
                };
            }
        }
    }
    
    print "   Component parts found: " . scalar(@component_parts) . "\n";
    print "   Host records found: " . scalar(@host_records) . "\n";
    print "   Orphan candidates (900xxx): " . scalar(@orphan_candidates) . "\n";
    if ($skipped > 0) {
        print "   ⚠️  Skipped $skipped record(s) with errors\n";
    }
    print "\n";
    
    if (@component_parts > 0) {
        print "   Sample component parts:\n";
        for (my $i = 0; $i < 3 && $i < @component_parts; $i++) {
            my $comp = $component_parts[$i];
            print "   - [$comp->{biblionumber}] $comp->{title}\n";
            print "     → Host: $comp->{host_ref}\n";
        }
        print "\n";
    }
    
    if (@orphan_candidates > 0) {
        print "   ✓ Orphan candidates found:\n";
        foreach my $orphan (@orphan_candidates) {
            print "   - [$orphan->{biblionumber}] $orphan->{title}\n";
            print "     → Missing: $orphan->{missing_host}\n";
        }
        print "\n";
    } else {
        print "   ⚠️  No orphan candidates found!\n";
        print "   Run populate_test_data.pl with --orphans option\n\n";
    }
    
    if (@host_records > 0) {
        print "   Sample host records:\n";
        for (my $i = 0; $i < 3 && $i < @host_records; $i++) {
            my $host = $host_records[$i];
            print "   - [$host->{biblionumber}] $host->{title}\n";
            print "     Control: $host->{control_number}\n";
        }
        print "\n";
    }
}

# Check 2: Elasticsearch configuration
print "2. Checking Elasticsearch configuration...\n";
my $es_config = C4::Context->config('elasticsearch');

if (!$es_config) {
    print "   ⚠️  Elasticsearch not configured in koha-conf.xml\n";
    print "   The orphan detection requires Elasticsearch\n\n";
} else {
    my $nodes = $es_config->{server}[0] || 'localhost:9200';
    my $index_name = $es_config->{index_name} || 'koha';
    
    print "   Nodes: $nodes\n";
    print "   Index prefix: $index_name\n";
    print "   Biblio index: ${index_name}_biblios\n\n";
    
    # Check 3: Test Elasticsearch connection
    print "3. Testing Elasticsearch connection...\n";
    eval {
        require Search::Elasticsearch;
        my $es = Search::Elasticsearch->new(
            nodes => $nodes,
        );
        
        my $info = $es->info();
        print "   ✓ Connected to Elasticsearch\n";
        print "   Version: " . $info->{version}{number} . "\n";
        
        # Check if index exists
        my $index_exists = $es->indices->exists(index => "${index_name}_biblios");
        if ($index_exists) {
            print "   ✓ Index '${index_name}_biblios' exists\n";
            
            # Get index stats
            my $stats = $es->indices->stats(index => "${index_name}_biblios");
            my $doc_count = $stats->{_all}{primaries}{docs}{count} || 0;
            print "   Documents in index: $doc_count\n";
            
            if ($doc_count == 0) {
                print "   ⚠️  Index is empty! Records need to be indexed.\n";
                print "   Reindex with: ~/Koha/misc/search_tools/rebuild_elasticsearch.pl -b -r -v\n";
            } elsif ($doc_count < $total_biblios) {
                print "   ⚠️  Some records may not be indexed ($doc_count indexed vs $total_biblios in DB)\n";
                print "   Consider reindexing\n";
            }
            
            # Check for records with 773 field in ES
            print "\n4. Checking for component parts in Elasticsearch...\n";
            my $query_result = $es->search(
                index => "${index_name}_biblios",
                body => {
                    query => {
                        bool => {
                            must => [
                                { exists => { field => 'record-control-number-773w' } }
                            ]
                        }
                    },
                    size => 3
                }
            );
            
            my $es_total = $query_result->{hits}{total};
            $es_total = $es_total->{value} if ref($es_total) eq 'HASH';
            
            print "   Component parts in ES: $es_total\n";
            
            if ($es_total > 0) {
                print "   Sample from Elasticsearch:\n";
                foreach my $hit (@{$query_result->{hits}{hits}}) {
                    my $source = $hit->{_source};
                    my $title = $source->{title}[0] || 'N/A';
                    my $w = $source->{'record-control-number-773w'}[0] || 'N/A';
                    print "   - $title → $w\n";
                }
            } else {
                print "   ⚠️  No component parts found in Elasticsearch!\n";
                print "   Records may need to be indexed.\n";
            }
            
        } else {
            print "   ⚠️  Index '${index_name}_biblios' does not exist\n";
            print "   Run rebuild_elasticsearch.pl to create and populate the index\n";
        }
        
    };
    
    if ($@) {
        print "   ✗ ERROR connecting to Elasticsearch: $@\n";
        print "   Make sure Elasticsearch is running and accessible\n";
    }
}

print "\n";
print "=" x 70 . "\n";
print "Setup check complete\n";
print "=" x 70 . "\n\n";

print "Summary:\n";
print "- Database records: " . ($total_biblios > 0 ? "✓ Found" : "✗ None") . "\n";
print "- ES configured: " . ($es_config ? "✓ Yes" : "✗ No") . "\n";
print "\n";

if ($total_biblios == 0) {
    print "Next step: Create test data\n";
    print "  ./populate_test_data.pl --hosts=10 --components=3 --orphans=5 --verbose\n";
} elsif (!$es_config) {
    print "Next step: Configure Elasticsearch in koha-conf.xml\n";
} else {
    print "Next step: Test orphan detection\n";
    print "  ./diagnose_orphans.pl\n";
}

1;

#!/usr/bin/perl

# Check actual Elasticsearch data structure

use Modern::Perl;
use C4::Context;
use Data::Dumper;

print "=" x 70 . "\n";
print "Elasticsearch Data Structure Check\n";
print "=" x 70 . "\n\n";

my $es_config = C4::Context->config('elasticsearch');

if (!$es_config) {
    print "ERROR: Elasticsearch not configured\n";
    exit 1;
}

my $nodes = $es_config->{server}[0] || 'localhost:9200';
my $index_name = $es_config->{index_name} || 'koha';
my $biblio_index = "${index_name}_biblios";

eval {
    require Search::Elasticsearch;
    my $es = Search::Elasticsearch->new(nodes => $nodes);
    
    print "Connected to Elasticsearch at: $nodes\n";
    print "Index: $biblio_index\n\n";
    
    # Get all records to see their structure
    print "1. Fetching sample records from Elasticsearch...\n";
    my $result = $es->search(
        index => $biblio_index,
        body => {
            query => { match_all => {} },
            size => 5
        }
    );
    
    my $total = $result->{hits}{total};
    $total = $total->{value} if ref($total) eq 'HASH';
    
    print "Total documents in index: $total\n\n";
    
    if ($total == 0) {
        print "⚠️  Index is empty! Run:\n";
        print "   1. ./populate_test_data.pl --verbose\n";
        print "   2. /usr/share/koha/bin/search_tools/rebuild_elasticsearch.pl -b -v\n";
        exit 1;
    }
    
    print "2. Sample record structures:\n";
    print "-" x 70 . "\n";
    
    my $count = 0;
    foreach my $hit (@{$result->{hits}{hits}}) {
        $count++;
        print "\nRecord $count (ID: $hit->{_id}):\n";
        my $source = $hit->{_source};
        
        # Show all fields
        foreach my $field (sort keys %$source) {
            my $value = $source->{$field};
            if (ref($value) eq 'ARRAY') {
                print "  $field: [" . join(", ", @$value) . "]\n";
            } else {
                print "  $field: $value\n";
            }
        }
    }
    
    print "\n" . "=" x 70 . "\n";
    print "3. Checking for 773 field data...\n";
    print "-" x 70 . "\n\n";
    
    # List all possible field names that might contain 773 data
    my @possible_773_fields = (
        'record-control-number-773w',
        'host-item',
        'host-item-entry',
        'linked-host',
        '773',
        'field_773',
    );
    
    print "Searching for these field names:\n";
    foreach my $field_name (@possible_773_fields) {
        print "  - $field_name\n";
    }
    print "\n";
    
    # Get index mapping to see what fields exist
    print "4. Getting index mapping...\n";
    my $mapping = $es->indices->get_mapping(index => $biblio_index);
    my $properties = $mapping->{$biblio_index}{mappings}{properties} || 
                     $mapping->{$biblio_index}{mappings}{data}{properties} || {};
    
    print "Fields in index:\n";
    my @all_fields = sort keys %$properties;
    my @related_773 = grep { /773|host|component|link/i } @all_fields;
    
    if (@related_773) {
        print "\nFields related to 773/host/component:\n";
        foreach my $field (@related_773) {
            print "  ✓ $field\n";
        }
    } else {
        print "No fields matching '773', 'host', 'component', or 'link' found\n";
    }
    
    print "\nAll fields (first 30):\n";
    for (my $i = 0; $i < 30 && $i < @all_fields; $i++) {
        print "  - $all_fields[$i]\n";
    }
    
    print "\n" . "=" x 70 . "\n";
    print "5. Testing specific queries...\n";
    print "-" x 70 . "\n\n";
    
    # Test query for component parts
    print "Query: Looking for 'record-control-number-773w' field...\n";
    my $comp_result = eval {
        $es->search(
            index => $biblio_index,
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
    };
    
    if ($@) {
        print "ERROR: $@\n";
    } elsif ($comp_result) {
        my $comp_total = $comp_result->{hits}{total};
        $comp_total = $comp_total->{value} if ref($comp_total) eq 'HASH';
        print "Found: $comp_total records\n";
        
        if ($comp_total > 0) {
            print "Sample records:\n";
            foreach my $hit (@{$comp_result->{hits}{hits}}) {
                print "  - ID: $hit->{_id}\n";
                print "    Fields: " . join(", ", sort keys %{$hit->{_source}}) . "\n";
            }
        }
    }
    
    print "\n" . "=" x 70 . "\n";
    print "Diagnostic complete\n";
    print "=" x 70 . "\n";
};

if ($@) {
    print "ERROR: $@\n";
}

1;

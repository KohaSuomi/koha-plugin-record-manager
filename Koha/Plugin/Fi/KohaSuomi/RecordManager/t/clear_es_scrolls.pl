#!/usr/bin/perl

# Clear all Elasticsearch scroll contexts

use Modern::Perl;
use C4::Context;

print "Clearing Elasticsearch scroll contexts...\n";

my $es_config = C4::Context->config('elasticsearch');

if (!$es_config) {
    print "ERROR: Elasticsearch not configured\n";
    exit 1;
}

my $nodes = $es_config->{server}[0] || 'localhost:9200';

eval {
    require Search::Elasticsearch;
    my $es = Search::Elasticsearch->new(nodes => $nodes);
    
    # Clear all scroll contexts
    $es->clear_scroll(scroll_id => '_all');
    
    print "✓ All scroll contexts cleared\n";
};

if ($@) {
    print "Error: $@\n";
    exit 1;
}

print "Done!\n";
1;

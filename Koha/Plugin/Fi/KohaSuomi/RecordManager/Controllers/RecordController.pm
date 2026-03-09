package Koha::Plugin::Fi::KohaSuomi::RecordManager::Controllers::RecordController;

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Try::Tiny;
use C4::Context;
use Koha::Plugins;
use Koha::Logger;
use Koha::Plugin::Fi::KohaSuomi::RecordManager;
use Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records;

sub list_orphans {
    ## This method handles the retrieval of orphan records
    ## Orphan records are component parts whose host records don't exist
    my $c = shift->openapi->valid_input or return;
    my $logger = Koha::Logger->get({ interface => 'api' });

    # Get pagination parameters
    my $page = $c->validation->param('page') || 1;
    my $per_page = $c->validation->param('per_page') || 20;
    
    # Validate parameters
    $page = 1 if $page < 1;
    $per_page = 20 if $per_page < 1 || $per_page > 100;

    try {
        my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
        my $result = $records->get_orphan_records({
            page => $page,
            per_page => $per_page
        });

        my $total = $result->{total};
        my $total_pages = int(($total + $per_page - 1) / $per_page);
        
        return $c->render(
            status => 200, 
            openapi => {
                orphans => $result->{orphans},
                pagination => {
                    page => $page,
                    per_page => $per_page,
                    total => $total,
                    total_pages => $total_pages
                }
            }
        );
    }
    catch {
        my $error = $_;
        $logger->error("Failed to retrieve orphan records: $error");
        return $c->render(
            status => 500, 
            openapi => { error => "Failed to retrieve orphan records: $error" }
        );
    };
}

1;


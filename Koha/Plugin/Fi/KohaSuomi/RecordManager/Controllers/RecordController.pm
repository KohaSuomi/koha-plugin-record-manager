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

sub find_possible_hosts {
    ## This method finds possible host records for a component part
    ## Uses the 773 (host-item) field data to search for matching records
    my $c = shift->openapi->valid_input or return;
    my $logger = Koha::Logger->get({ interface => 'api' });

    # Get biblionumber from path parameter
    my $biblionumber = $c->validation->param('biblionumber');
    
    unless ($biblionumber) {
        return $c->render(
            status => 400,
            openapi => { error => "biblionumber is required" }
        );
    }

    try {
        my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
        my $result = $records->find_possible_hosts($biblionumber);

        # Check if there was an error
        if ($result->{error}) {
            return $c->render(
                status => 404,
                openapi => { error => $result->{error} }
            );
        }

        return $c->render(
            status => 200, 
            openapi => {
                biblionumber => $biblionumber,
                possible_hosts => $result->{possible_hosts},
                total => $result->{total},
                component_data => $result->{component_data}
            }
        );
    }
    catch {
        my $error = $_;
        $logger->error("Failed to find possible hosts for biblionumber $biblionumber: $error");
        return $c->render(
            status => 500, 
            openapi => { error => "Failed to find possible hosts: $error" }
        );
    };
}

sub combine_orphan_to_host {
    ## This method combines an orphan record to a host record
    ## Updates the orphan's 773$w field with the host's control number
    my $c = shift->openapi->valid_input or return;
    my $logger = Koha::Logger->get({ interface => 'api' });

    # Get parameters from request body
    my $body = $c->validation->param('body');
    my $orphan_biblionumber = $body->{orphan_biblionumber};
    my $host_biblionumber = $body->{host_biblionumber};
    
    # Validate parameters
    unless ($orphan_biblionumber) {
        return $c->render(
            status => 400,
            openapi => { error => "orphan_biblionumber is required" }
        );
    }
    
    unless ($host_biblionumber) {
        return $c->render(
            status => 400,
            openapi => { error => "host_biblionumber is required" }
        );
    }

    try {
        my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
        my $result = $records->combine_orphan_to_host($orphan_biblionumber, $host_biblionumber);

        if ($result->{error}) {
            return $c->render(
                status => 400,
                openapi => { error => $result->{message} }
            );
        } else {
            return $c->render(
                status => 200,
                openapi => { message => "Updated successfully" }
            );
        }

        
    }
    catch {
        my $error = $_;
        $logger->error("Failed to combine orphan to host: $error");
        return $c->render(
            status => 500, 
            openapi => { error => "Failed to combine orphan to host: $error" }
        );
    };
}

1;


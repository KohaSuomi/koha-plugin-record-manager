#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 5;
use Test::Mojo;
use Koha::Database;
use t::lib::TestBuilder;
use t::lib::Mocks;
use C4::Biblio;
use MARC::Record;
use MARC::Field;

=head1 NAME

t::list_orphans - Test suite for listing orphan records API

=head1 DESCRIPTION

This test suite verifies the functionality of the orphan records API endpoint
in the Koha Record Manager plugin. It tests pagination, authentication, and
error handling for the /records/orphans endpoint.

=head1 EXAMPLE

To run the tests, execute the following command:

    perl t/list_orphans.t
    
or 

    prove Koha/Plugin/Fi/KohaSuomi/RecordManager/t/list_orphans.t

=cut

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

# Mock orphan records data
# These are component parts whose host records (773$w) don't exist
sub _create_mock_orphans {
    my ($builder, $count) = @_;
    $count ||= 25;
    
    my @orphans;
    for (my $i = 1; $i <= $count; $i++) {
        # Create a MARC record for component part
        my $marc = MARC::Record->new();
        my $title_field = MARC::Field->new('245', '0', '0', 'a' => "Component Part $i: Test Article");
        my $author_field = MARC::Field->new('100', '0', '0', 'a' => "Test Author $i");
        
        # Add MARC field 773 to indicate it's a component part
        # 773$w contains the control number of the (missing) host record
        my $field773 = MARC::Field->new(
            '773', '0', '8',
            't' => "Missing Host Record $i",  # Host title
            'w' => "(FI-MELINDA)" . (900000 + $i),  # Non-existent control number
        );
        
        $marc->append_fields($title_field, $author_field, $field773);
        
        # Add the biblio using C4::Biblio::AddBiblio
        my ($biblionumber, $biblioitemnumber) = C4::Biblio::AddBiblio($marc, '');
        
        push @orphans, {
            biblionumber => $biblionumber,
            control_number => (900000 + $i),
            cni => 'FI-MELINDA',
            title => "Component Part $i: Test Article",
            host_title => "Missing Host Record $i",
        };
    }
    
    return \@orphans;
}



subtest 'GET orphan records with default pagination' => sub {
    plan tests => 9;
    
    # Begin transaction
    $schema->storage->txn_begin;
    
    # Create a test patron with catalogue permissions
    my $patron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 1 }    # superlibrarian for simplicity, or use catalogue permission
    });
    my $password = 'thePassword123';
    $patron->set_password({ password => $password, skip_validation => 1 });
    
    # Get the patron's userid
    my $userid = $patron->userid;
    
    # Create 5 mock orphan records
    my $orphans = _create_mock_orphans($builder, 5);
    
    # Call the API endpoint with user credentials
    my $response = $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/records/orphans")
        ->status_is(200)
        ->json_has('/orphans', 'Response has orphans array')
        ->json_has('/pagination', 'Response has pagination object')
        ->json_has('/pagination/page', 'Pagination has page field')
        ->json_has('/pagination/per_page', 'Pagination has per_page field')
        ->json_has('/pagination/total', 'Pagination has total field')
        ->json_has('/pagination/total_pages', 'Pagination has total_pages field');
    
    # Verify we got orphan records (assuming Elasticsearch is available)
    # Note: This test may pass even with 0 orphans if ES is not configured
    is(ref($response->tx->res->json->{orphans}), 'ARRAY', 'Orphans is an array');
    
    # Rollback the transaction
    $schema->storage->txn_rollback;
};

subtest 'GET orphan records with custom pagination' => sub {
    plan tests => 10;
    
    # Begin transaction
    $schema->storage->txn_begin;
    
    # Create a test patron with catalogue permissions
    my $patron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 1 }
    });
    my $password = 'thePassword123';
    $patron->set_password({ password => $password, skip_validation => 1 });
    
    my $userid = $patron->userid;
    
    # Test with custom page and per_page parameters
    my $response = $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/records/orphans?page=2&per_page=10")
        ->status_is(200)
        ->json_has('/orphans')
        ->json_has('/pagination')
        ->json_is('/pagination/page', 2, 'Page is 2')
        ->json_is('/pagination/per_page', 10, 'Per page is 10');
    
    # Test with page 1 and per_page 50
    $response = $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/records/orphans?page=1&per_page=50")
        ->status_is(200)
        ->json_is('/pagination/page', 1, 'Page is 1')
        ->json_is('/pagination/per_page', 50, 'Per page is 50');
    
    # Rollback the transaction
    $schema->storage->txn_rollback;
};

subtest 'GET orphan records with invalid pagination parameters' => sub {
    plan tests => 6;
    
    # Begin transaction
    $schema->storage->txn_begin;
    
    # Create a test patron with catalogue permissions
    my $patron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 1 }
    });
    my $password = 'thePassword123';
    $patron->set_password({ password => $password, skip_validation => 1 });
    
    my $userid = $patron->userid;
    
    # Test with page = 0 (should be rejected as invalid - minimum is 1)
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/records/orphans?page=0")
        ->status_is(400, 'Invalid page 0 returns 400 Bad Request');
    
    # Test with negative page (should be rejected as invalid)
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/records/orphans?page=-5")
        ->status_is(400, 'Negative page returns 400 Bad Request');
    
    # Test with per_page > 100 (should be rejected as invalid - maximum is 100)
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/records/orphans?per_page=150")
        ->status_is(400, 'Per_page > 100 returns 400 Bad Request');
    
    # Rollback the transaction
    $schema->storage->txn_rollback;
};

subtest 'GET orphan records without authentication' => sub {
    plan tests => 2;
    
    # Begin transaction
    $schema->storage->txn_begin;
    
    # Attempt to access without credentials
    $t->get_ok("/api/v1/contrib/kohasuomi/records/orphans")
        ->status_is(401);
    
    # Rollback the transaction
    $schema->storage->txn_rollback;
};

subtest 'GET orphan records with insufficient permissions' => sub {
    plan tests => 2;
    
    # Begin transaction
    $schema->storage->txn_begin;
    
    # Create a patron without catalogue permissions
    my $patron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 0 }
    });
    my $password = 'thePassword123';
    $patron->set_password({ password => $password, skip_validation => 1 });
    
    my $userid = $patron->userid;
    
    # Attempt to access without proper permissions
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/records/orphans")
        ->status_is(403);
    
    # Rollback the transaction
    $schema->storage->txn_rollback;
};

=head1 AUTHOR

Johanna Räisä <johanna.raisa@koha-suomi.fi>

=head1 LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;

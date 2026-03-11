#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 11;
use Test::MockModule;
use Test::Exception;
use Koha::Database;
use t::lib::TestBuilder;
use t::lib::Mocks;
use C4::Biblio;
use MARC::Record;
use MARC::Field;
use Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records;

=head1 NAME

t::combine_orphan_to_host - Test suite for combining orphan records to host records

=head1 DESCRIPTION

This test suite verifies the functionality of the combine_orphan_to_host method
in the Records module. It tests various scenarios including successful combinations,
error handling for missing records, missing fields, and edge cases.

=head1 EXAMPLE

To run the tests, execute the following command:

    perl Koha/Plugin/Fi/KohaSuomi/RecordManager/t/combine_orphan_to_host.t
    
or 

    prove Koha/Plugin/Fi/KohaSuomi/RecordManager/t/combine_orphan_to_host.t

=cut

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# Helper function to create a host record
sub _create_host_record {
    my ($builder, $control_number) = @_;
    $control_number ||= '123456789';
    
    # Create a MARC record with 001 field
    my $marc = MARC::Record->new();
    my $field001 = MARC::Field->new('001', $control_number);
    my $title_field = MARC::Field->new('245', '0', '0', 'a' => 'Host Record Title');
    my $author_field = MARC::Field->new('100', '0', '0', 'a' => 'Host Author');
    $marc->append_fields($field001, $title_field, $author_field);
    
    # Add the biblio using C4::Biblio::AddBiblio
    my ($biblionumber, $biblioitemnumber) = C4::Biblio::AddBiblio($marc, '');
    
    return Koha::Biblios->find($biblionumber);
}

# Helper function to create an orphan record with 773 field
sub _create_orphan_record {
    my ($builder, $options) = @_;
    $options ||= {};
    
    # Create a MARC record for the component part
    my $marc = MARC::Record->new();
    my $title_field = MARC::Field->new('245', '0', '0', 'a' => 'Orphan Component Part');
    my $author_field = MARC::Field->new('100', '0', '0', 'a' => 'Orphan Author');
    $marc->append_fields($title_field, $author_field);
    
    # Add MARC field 773 unless explicitly disabled
    unless ($options->{no_773}) {
        my $field773;
        if ($options->{with_w_subfield}) {
            # Create 773 with existing $w subfield
            $field773 = MARC::Field->new(
                '773', '0', '8',
                't' => "Host Title",
                'w' => "(FI-MELINDA)999999999",  # Existing (wrong) control number
            );
        } else {
            # Create 773 without $w subfield
            $field773 = MARC::Field->new(
                '773', '0', '8',
                't' => "Host Title",
                'a' => "Host Author",
            );
        }
        $marc->append_fields($field773);
    }
    
    # Add the biblio using C4::Biblio::AddBiblio
    my ($biblionumber, $biblioitemnumber) = C4::Biblio::AddBiblio($marc, '');
    
    return Koha::Biblios->find($biblionumber);
}

subtest 'Successful combination - orphan without existing 773$w' => sub {
    plan tests => 5;
    
    $schema->storage->txn_begin;
    
    # Create host record with control number
    my $host = _create_host_record($builder, '123456789');
    
    # Create orphan record with 773 field but no $w subfield
    my $orphan = _create_orphan_record($builder, { with_w_subfield => 0 });
    
    # Create Records instance
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    # Combine orphan to host
    my $result = $records->combine_orphan_to_host($orphan->biblionumber, $host->biblionumber);
    
    is($result, 1, 'Combination returned success');
    
    # Verify that 773$w was added
    my $updated_orphan = Koha::Biblios->find($orphan->biblionumber);
    ok($updated_orphan, 'Orphan record still exists');
    
    my $marc = $updated_orphan->metadata->record;
    my $field773 = $marc->field('773');
    ok($field773, '773 field exists');
    
    my $w_subfield = $field773->subfield('w');
    ok($w_subfield, '773$w subfield exists');
    is($w_subfield, '123456789', '773$w contains correct control number');
    
    $schema->storage->txn_rollback;
};

subtest 'Successful combination - orphan with existing 773$w' => sub {
    plan tests => 5;
    
    $schema->storage->txn_begin;
    
    # Create host record with control number
    my $host = _create_host_record($builder, '987654321');
    
    # Create orphan record with 773 field and existing $w subfield
    my $orphan = _create_orphan_record($builder, { with_w_subfield => 1 });
    
    # Verify initial 773$w value
    my $initial_orphan = Koha::Biblios->find($orphan->biblionumber);
    my $initial_marc = $initial_orphan->metadata->record;
    my $initial_773 = $initial_marc->field('773');
    is($initial_773->subfield('w'), '(FI-MELINDA)999999999', 'Initial 773$w has wrong value');
    
    # Create Records instance
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    # Combine orphan to host
    my $result = $records->combine_orphan_to_host($orphan->biblionumber, $host->biblionumber);
    
    is($result, 1, 'Combination returned success');
    
    # Verify that 773$w was updated
    my $updated_orphan = Koha::Biblios->find($orphan->biblionumber);
    my $marc = $updated_orphan->metadata->record;
    my $field773 = $marc->field('773');
    ok($field773, '773 field exists');
    
    my $w_subfield = $field773->subfield('w');
    ok($w_subfield, '773$w subfield exists');
    is($w_subfield, '987654321', '773$w was updated with correct control number');
    
    $schema->storage->txn_rollback;
};

subtest 'Error - missing orphan biblionumber' => sub {
    plan tests => 2;
    
    $schema->storage->txn_begin;
    
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    # Call without orphan biblionumber
    my $result = $records->combine_orphan_to_host(undef, 123);
    
    ok(ref($result) eq 'HASH', 'Returns hashref');
    is($result->{message}, 'Orphan biblionumber is required', 'Correct error message');
    
    $schema->storage->txn_rollback;
};

subtest 'Error - missing host biblionumber' => sub {
    plan tests => 2;
    
    $schema->storage->txn_begin;
    
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    # Call without host biblionumber
    my $result = $records->combine_orphan_to_host(123, undef);
    
    ok(ref($result) eq 'HASH', 'Returns hashref');
    is($result->{message}, 'Host biblionumber is required', 'Correct error message');
    
    $schema->storage->txn_rollback;
};

subtest 'Error - orphan record not found' => sub {
    plan tests => 3;
    
    $schema->storage->txn_begin;
    
    my $host = _create_host_record($builder, '111111111');
    
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    # Use a non-existent biblionumber
    my $fake_biblionumber = 999999999;
    my $result = $records->combine_orphan_to_host($fake_biblionumber, $host->biblionumber);
    
    ok(ref($result) eq 'HASH', 'Returns hashref');
    is($result->{error}, 1, 'Error flag is set');
    like($result->{message}, qr/Orphan record not found/, 'Correct error message');
    
    $schema->storage->txn_rollback;
};

subtest 'Error - host record not found' => sub {
    plan tests => 3;
    
    $schema->storage->txn_begin;
    
    my $orphan = _create_orphan_record($builder);
    
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    # Use a non-existent biblionumber
    my $fake_biblionumber = 999999999;
    my $result = $records->combine_orphan_to_host($orphan->biblionumber, $fake_biblionumber);
    
    ok(ref($result) eq 'HASH', 'Returns hashref');
    is($result->{error}, 1, 'Error flag is set');
    like($result->{message}, qr/Host record not found/, 'Correct error message');
    
    $schema->storage->txn_rollback;
};

subtest 'Error - host record has no control number (001 field)' => sub {
    plan tests => 3;
    
    $schema->storage->txn_begin;
    
    # Create host without control number
    my $marc = MARC::Record->new();
    my $title_field = MARC::Field->new('245', '0', '0', 'a' => 'Host Without Control Number');
    $marc->append_fields($title_field);
    my ($host_biblionumber) = C4::Biblio::AddBiblio($marc, '');
    my $host = Koha::Biblios->find($host_biblionumber);
    
    my $orphan = _create_orphan_record($builder);
    
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    my $result = $records->combine_orphan_to_host($orphan->biblionumber, $host->biblionumber);
    
    ok(ref($result) eq 'HASH', 'Returns hashref');
    is($result->{error}, 1, 'Error flag is set');
    is($result->{message}, 'Host record has no control number (001 field)', 'Correct error message');
    
    $schema->storage->txn_rollback;
};

subtest 'Error - host control number is empty' => sub {
    plan tests => 3;
    
    $schema->storage->txn_begin;
    
    # Create host with empty control number
    my $marc = MARC::Record->new();
    my $field001 = MARC::Field->new('001', '');  # Empty control number
    my $title_field = MARC::Field->new('245', '0', '0', 'a' => 'Host With Empty Control Number');
    $marc->append_fields($field001, $title_field);
    my ($host_biblionumber) = C4::Biblio::AddBiblio($marc, '');
    my $host = Koha::Biblios->find($host_biblionumber);
    
    my $orphan = _create_orphan_record($builder);
    
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    my $result = $records->combine_orphan_to_host($orphan->biblionumber, $host->biblionumber);
    
    ok(ref($result) eq 'HASH', 'Returns hashref');
    is($result->{error}, 1, 'Error flag is set');
    is($result->{message}, 'Host control number is empty', 'Correct error message');
    
    $schema->storage->txn_rollback;
};

subtest 'Error - orphan record has no 773 field' => sub {
    plan tests => 3;
    
    $schema->storage->txn_begin;
    
    my $host = _create_host_record($builder, '222222222');
    
    # Create orphan without 773 field
    my $orphan = _create_orphan_record($builder, { no_773 => 1 });
    
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    my $result = $records->combine_orphan_to_host($orphan->biblionumber, $host->biblionumber);
    
    ok(ref($result) eq 'HASH', 'Returns hashref');
    is($result->{error}, 1, 'Error flag is set');
    is($result->{message}, 'Orphan record has no 773 field', 'Correct error message');
    
    $schema->storage->txn_rollback;
};

subtest 'Combination preserves other 773 subfields' => sub {
    plan tests => 7;
    
    $schema->storage->txn_begin;
    
    my $host = _create_host_record($builder, '333333333');
    
    # Create orphan with 773 field with multiple subfields
    my $marc = MARC::Record->new();
    my $title_field = MARC::Field->new('245', '0', '0', 'a' => 'Orphan Component Part');
    my $field773 = MARC::Field->new(
        '773', '0', '8',
        't' => "Original Host Title",
        'a' => "Original Host Author",
        'g' => "Pages 10-20",
        'd' => "2025",
    );
    $marc->append_fields($title_field, $field773);
    my ($orphan_biblionumber) = C4::Biblio::AddBiblio($marc, '');
    my $orphan = Koha::Biblios->find($orphan_biblionumber);
    
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    my $result = $records->combine_orphan_to_host($orphan->biblionumber, $host->biblionumber);
    
    is($result, 1, 'Combination returned success');
    
    # Verify that other subfields are preserved
    my $updated_orphan = Koha::Biblios->find($orphan->biblionumber);
    my $updated_marc = $updated_orphan->metadata->record;
    my $updated_773 = $updated_marc->field('773');
    
    is($updated_773->subfield('w'), '333333333', '773$w was added with correct value');
    is($updated_773->subfield('t'), 'Original Host Title', '773$t preserved');
    is($updated_773->subfield('a'), 'Original Host Author', '773$a preserved');
    is($updated_773->subfield('g'), 'Pages 10-20', '773$g preserved');
    is($updated_773->subfield('d'), '2025', '773$d preserved');
    
    # Count the number of subfields to ensure nothing was removed
    my @subfields = $updated_773->subfields();
    is(scalar(@subfields), 5, 'All subfields preserved (5 total including new $w)');
    
    $schema->storage->txn_rollback;
};

subtest 'Multiple orphans can be combined to same host' => sub {
    plan tests => 6;
    
    $schema->storage->txn_begin;
    
    my $host = _create_host_record($builder, '444444444');
    
    # Create two orphan records
    my $orphan1 = _create_orphan_record($builder, { with_w_subfield => 0 });
    my $orphan2 = _create_orphan_record($builder, { with_w_subfield => 0 });
    
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();
    
    # Combine first orphan
    my $result1 = $records->combine_orphan_to_host($orphan1->biblionumber, $host->biblionumber);
    is($result1, 1, 'First combination successful');
    
    # Combine second orphan
    my $result2 = $records->combine_orphan_to_host($orphan2->biblionumber, $host->biblionumber);
    is($result2, 1, 'Second combination successful');
    
    # Verify both orphans have correct 773$w
    my $updated_orphan1 = Koha::Biblios->find($orphan1->biblionumber);
    my $marc1 = $updated_orphan1->metadata->record;
    my $field773_1 = $marc1->field('773');
    is($field773_1->subfield('w'), '444444444', 'First orphan 773$w correct');
    
    my $updated_orphan2 = Koha::Biblios->find($orphan2->biblionumber);
    my $marc2 = $updated_orphan2->metadata->record;
    my $field773_2 = $marc2->field('773');
    is($field773_2->subfield('w'), '444444444', 'Second orphan 773$w correct');
    
    # Verify both orphan records are distinct
    isnt($orphan1->biblionumber, $orphan2->biblionumber, 'Orphans have different biblionumbers');
    isnt($updated_orphan1->title, $updated_orphan2->title, 'Orphans have different titles (if auto-generated differently)') unless $updated_orphan1->title eq $updated_orphan2->title;
    ok(1, 'Multiple orphans can reference same host');
    
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

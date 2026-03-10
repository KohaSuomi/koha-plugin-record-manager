package Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records;

# Copyright 2026 KohaSuomi
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use strict;
use warnings;
use C4::Context;
use Try::Tiny;
use C4::Biblio;
use Koha::Biblios;
use Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search;

=head1 NAME

Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records - Records module for Record Manager plugin

=head1 SYNOPSIS

    use Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records;
    
    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();

=head1 DESCRIPTION

This module provides record management functionality for the Record Manager plugin.

=head1 METHODS

=cut

=head2 new

    my $records = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Records->new();

Constructor

=cut

sub new {
    my ($class, $params) = @_;
    
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;
}

=head2 get_orphan_records

    my $result = $records->get_orphan_records({ page => 1, per_page => 20 });

Retrieve orphan bibliographic records (component parts whose host records don't exist)
Supports pagination via page and per_page parameters.

=cut

sub get_orphan_records {
    my ($self, $params) = @_;
    
    my $page = $params->{page} || 1;
    my $per_page = $params->{per_page} || 20;

    my $search = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search->new({size => 10});
    my ($scroll_id, $results, $total) = $search->search_component_parts();
    print "Total component parts found: $total\n";
    my @all_orphans;
    my $processed = 0;
    
    try {
        
        while ($results && @{$results->{hits}{hits}}) {
            foreach my $hit (@{$results->{hits}{hits}}) {
                my $component    = $hit->{_source};
                my $component_id = $hit->{_id};
                my $w            = $component->{'record-control-number-773w'}[0];
                my $cni          = $component->{'cni'}[0];
                my $control_number = $component->{'control-number'}[0] || '';
                #next unless $cni =~ /^(FI-MELINDA|FI-BTJ|FI-TATI)$/;
                next unless $w;
                my ($host_control_number) = $w =~ /(\d+)/;
                my $host_cni_control_number = "($cni)$host_control_number";
                
                # Check if host record does not exist
                if ( !$self->host_record_exists($host_control_number, $host_cni_control_number) ) {
                    push @all_orphans, {
                        id => $component_id,
                        control_number => $control_number || '',
                        control_number_identifier => $cni || '',
                        title => $component->{'title'}[0] || '',
                        author => $component->{'author'}[0] || '',
                        'host_item' => $component->{'host-item'}[0] || '',
                        '773w' => $component->{'record-control-number-773w'}[0] || '',
                    };
                }
                $processed++;
            }
            
            # Get next batch
            last if $processed >= $total;
            $results = $search->scroll_search($scroll_id);
        }

        # Clear the scroll context
        $search->clear_scroll($scroll_id) if $scroll_id;
        
        # Apply pagination
        my $total_orphans = scalar @all_orphans;
        my $start = ($page - 1) * $per_page;
        my $end = $start + $per_page - 1;
        $end = $total_orphans - 1 if $end >= $total_orphans;
        
        my @paginated_orphans = $start < $total_orphans ? @all_orphans[$start .. $end] : ();
        
        return {
            orphans => \@paginated_orphans,
            total => $total_orphans
        };
    } catch {
        $search->clear_scroll($scroll_id) if $scroll_id;
        die "Error while retrieving orphan records: $_";
    };
}

=head2 host_record_exists

    my $exists = $records->host_record_exists($control_number, $cni_control_number);

Check if a host record exists by control number 

=cut

sub host_record_exists {
    my ($self, $control_number, $cni_control_number) = @_;
    
    return 0 unless $control_number;

    my $search = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search->new({size => 1});
    my ($results, $total) = $search->search_host_records($control_number, $cni_control_number);
    
    # Return true (1) if host record exists (total > 0), false (0) otherwise
    return $total > 0 ? 1 : 0;
}

=head2 find_possible_hosts

    my $result = $records->find_possible_hosts($component_biblionumber);

Find possible host records for a component part by searching Elasticsearch using
the host-item field (773) data. This is useful when the control number doesn't
match any existing record but the record might still exist with different metadata.

Parameters:
    $component_biblionumber - the biblionumber of the component part

Returns:
    hashref containing:
        - possible_hosts: arrayref of potential host records with score
        - total: total number of potential hosts found
        - component_data: data from the component part used for searching

=cut

sub find_possible_hosts {
    my ($self, $component_biblionumber) = @_;
    
    return { possible_hosts => [], total => 0, error => 'No biblionumber provided' }
        unless $component_biblionumber;
    
    # Get the component part record from Koha
    my $biblio = Koha::Biblios->find($component_biblionumber);
    return { possible_hosts => [], total => 0, error => 'Record not found' }
        unless $biblio;
    
    my $marcrecord = $biblio->metadata->record;
    return { possible_hosts => [], total => 0, error => 'No MARC record found' }
        unless $marcrecord;
    
    # Extract host-item field data (773)
    my $field_773 = $marcrecord->field('773');
    return { possible_hosts => [], total => 0, error => 'No 773 field found' }
        unless $field_773;
    
    # Extract relevant subfields from 773
    my $host_item_data = {};
    $host_item_data->{title}  = $field_773->subfield('t') if $field_773->subfield('t');
    $host_item_data->{author} = $field_773->subfield('a') if $field_773->subfield('a');
    $host_item_data->{isbn}   = $field_773->subfield('z') if $field_773->subfield('z');
    $host_item_data->{issn}   = $field_773->subfield('x') if $field_773->subfield('x');
    
    return { possible_hosts => [], total => 0, error => 'No searchable data in 773 field' }
        unless keys %$host_item_data;
    
    # Search for possible hosts
    my $search = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search->new({size => 10});
    my ($results, $total) = $search->search_possible_hosts($host_item_data);
    
    my @possible_hosts;
    if ($results && $results->{hits}{hits}) {
        foreach my $hit (@{$results->{hits}{hits}}) {
            my $source = $hit->{_source};
            
            # Extract hit data
            my $hit_title = $source->{title}[0] || '';
            my $hit_author = $source->{author}[0] || '';
            my $hit_isbn = $source->{isbn}[0] || '';
            my $hit_issn = $source->{issn}[0] || '';
            
            # Filter: only include hits that have actual similarity to search criteria
            my $matches = 0;
            
            # Check title similarity (case-insensitive partial match)
            if ($host_item_data->{title} && $hit_title) {
                my $search_title = lc($host_item_data->{title});
                my $result_title = lc($hit_title);
                if (index($result_title, $search_title) != -1 || index($search_title, $result_title) != -1) {
                    $matches++;
                }
            }
            
            # Check author similarity (case-insensitive partial match)
            if ($host_item_data->{author} && $hit_author) {
                my $search_author = lc($host_item_data->{author});
                my $result_author = lc($hit_author);
                if (index($result_author, $search_author) != -1 || index($search_author, $result_author) != -1) {
                    $matches++;
                }
            }
            
            # Check ISBN match (exact match, normalized)
            if ($host_item_data->{isbn} && $hit_isbn) {
                my $search_isbn = $host_item_data->{isbn};
                my $result_isbn = $hit_isbn;
                $search_isbn =~ s/[^0-9X]//gi;
                $result_isbn =~ s/[^0-9X]//gi;
                if (lc($search_isbn) eq lc($result_isbn)) {
                    $matches += 2; # ISBN is stronger match
                }
            }
            
            # Check ISSN match (exact match, normalized)
            if ($host_item_data->{issn} && $hit_issn) {
                my $search_issn = $host_item_data->{issn};
                my $result_issn = $hit_issn;
                $search_issn =~ s/[^0-9X]//gi;
                $result_issn =~ s/[^0-9X]//gi;
                if (lc($search_issn) eq lc($result_issn)) {
                    $matches += 2; # ISSN is stronger match
                }
            }
            
            # Only include if there's at least one match
            next unless $matches > 0;
            
            push @possible_hosts, {
                biblionumber => $hit->{_id},
                score => $hit->{_score},
                title => $hit_title,
                author => $hit_author,
                control_number => $source->{'control-number'}[0] || '',
                isbn => $hit_isbn,
                issn => $hit_issn,
            };
        }
    }
    
    return {
        possible_hosts => \@possible_hosts,
        total => scalar(@possible_hosts),
        component_data => $host_item_data,
    };
}

=head2 combine_orphan_to_host

    my $result = $records->combine_orphan_to_host($orphan_biblionumber, $host_biblionumber);

Combine an orphan record to a host record by updating the orphan's 773$w field
with the host's control number (001 field).

Parameters:
    $orphan_biblionumber - the biblionumber of the orphan (component part) record
    $host_biblionumber   - the biblionumber of the host record

Returns:
    On success: 1
    On error: hashref containing:
        - error: 1 to indicate an error occurred
        - message: descriptive error message

=cut

sub combine_orphan_to_host {
    my ($self, $orphan_biblionumber, $host_biblionumber) = @_;
    
    # Validate parameters
    return { error => 1, message => 'Orphan biblionumber is required' }
        unless $orphan_biblionumber;
    return { error => 1, message => 'Host biblionumber is required' }
        unless $host_biblionumber;
    
    # Get the orphan record
    my $orphan_biblio = Koha::Biblios->find($orphan_biblionumber);
    return { error => 1, message => "Orphan record not found: $orphan_biblionumber" }
        unless $orphan_biblio;
    
    # Get the host record
    my $host_biblio = Koha::Biblios->find($host_biblionumber);
    return { error => 1, message => "Host record not found: $host_biblionumber" }
        unless $host_biblio;
    
    # Get MARC records
    my $orphan_marcrecord = $orphan_biblio->metadata->record;
    return { error => 1, message => 'Orphan MARC record not found' }
        unless $orphan_marcrecord;
    
    my $host_marcrecord = $host_biblio->metadata->record;
    return { error => 1, message => 'Host MARC record not found' }
        unless $host_marcrecord;
    
    # Get host's control number (001 field)
    my $host_control_number_field = $host_marcrecord->field('001');
    return { error => 1, message => 'Host record has no control number (001 field)' }
        unless $host_control_number_field;
    
    my $host_control_number = $host_control_number_field->data();
    return { error => 1, message => 'Host control number is empty' }
        unless $host_control_number;
    
    # Check if orphan has 773 field
    my $field_773 = $orphan_marcrecord->field('773');
    return { error => 1, message => 'Orphan record has no 773 field' }
        unless $field_773;
    
    # Update 773$w with host's control number
    # First, check if $w subfield exists
    if ($field_773->subfield('w')) {
        # Update existing $w subfield
        $field_773->update('w' => $host_control_number);
    } else {
        # Add new $w subfield
        $field_773->add_subfields('w' => $host_control_number);
    }
    
    # Save the updated orphan record
    my $frameworkcode = $orphan_biblio->frameworkcode;
    C4::Biblio::ModBiblio($orphan_marcrecord, $orphan_biblionumber, $frameworkcode);
    
    return 1;
}

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

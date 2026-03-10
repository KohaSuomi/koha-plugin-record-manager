package Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search;

# Copyright 2026 Koha-Suomi Oy
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
use C4::Context;
use Search::Elasticsearch;
use Data::Dumper;

=head1 NAME

Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search - Search module for Record Manager plugin

=head1 SYNOPSIS

    use Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search;
    
    my $search = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search->new();

=head1 DESCRIPTION

This module provides search functionality for the Record Manager plugin.

=head1 METHODS

=cut

=head2 new

    my $search = Koha::Plugin::Fi::KohaSuomi::RecordManager::Modules::Search->new();

Constructor

=cut

sub new {
    my ($class, $params) = @_;
    
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;
}

sub config {
    my ($self) = @_;
    return C4::Context->config('elasticsearch');
}

sub index_name {
    my ($self) = @_;
    my $config_file = $self->config();
    return $config_file->{'index_name'}.'_biblios';
}

sub nodes {
    my ($self) = @_;
    my $config_file = $self->config();
    return $config_file->{'server'}[0] || 'localhost:9200';
}

sub elasticsearch_client {
    my ($self) = @_;
    my $es = Search::Elasticsearch->new(
        nodes => $self->nodes(),
    );
    return $es;
}

sub size {
    return shift->{_params}->{size} // 1000;
}

=head2 search_records

    my $results = $search->search_records($query, $params);

Search for records based on query and parameters

=cut

sub search_records {
    my ($self, $body, $params) = @_;

    $body->{size} = $params->{size} // $self->size();
    my $results = $self->elasticsearch_client()->search(
        index => $self->index_name(),
        body  => $body,
        scroll => '2m',
    );

    my $scroll_id = $results->{_scroll_id};
    my $total = $results->{hits}{total};
    # In ES 7.x+, total can be a hashref: { value => N, relation => 'eq' }
    $total = $total->{value} if ref($total) eq 'HASH';
    
    return ($scroll_id, $results, $total);
}

sub search_records_no_scroll {
    my ($self, $body, $params) = @_;

    $body->{size} = $params->{size} // 1;
    my $results = $self->elasticsearch_client()->search(
        index => $self->index_name(),
        body  => $body,
        # NO scroll parameter - this is a simple query
    );

    my $total = $results->{hits}{total};
    # In ES 7.x+, total can be a hashref: { value => N, relation => 'eq' }
    $total = $total->{value} if ref($total) eq 'HASH';
    
    return ($results, $total);
}

sub search_host_records {
    my ($self, $control_number, $cni_control_number) = @_;
    
    # Search for host records by control number
    # Host records should NOT have 773$w (they are hosts, not component parts)
    my $query = {
        query => {
            bool => {
                should => [
                    { term => { 'system-control-number' => $control_number } },
                    { term => { 'system-control-number' => $cni_control_number } },
                    { term => { 'control-number' => $control_number } },
                    { term => { 'control-number' => $cni_control_number } },
                ],
                minimum_should_match => 1,
                must_not => [
                    # Exclude component parts (which have 773 field)
                    { exists => { field => 'record-control-number-773w' } },
                ],
            },
        }
    };
    
    # Use non-scrolling search since we only need to check existence (size=1)
    my ($results, $total) = $self->search_records_no_scroll($query, {size => 1});
    
    return ($results, $total);
}

sub search_component_parts {
    my ($self) = @_;

    my ($scroll_id, $results, $total) = $self->search_records(
        {
            query => {
                bool => {
                    must => [
                        { exists => { field => 'record-control-number-773w' } },
                    ],
                },
            }
        },
    );    

    return ($scroll_id, $results, $total);
}

sub scroll_search {
    my ($self, $scroll_id) = @_;

    my $results = $self->elasticsearch_client()->scroll(
        scroll_id => $scroll_id,
        scroll    => '2m',
    );

    return $results;
}

sub clear_scroll {
    my ($self, $scroll_id) = @_;
    print "Clearing scroll context\n";
    $self->elasticsearch_client()->clear_scroll(
        scroll_id => $scroll_id,
    );
}

=head2 search_possible_hosts

    my ($results, $total) = $search->search_possible_hosts($host_item_data);

Search for possible host records based on host-item field data from component parts.
Uses title, author, and other metadata from the 773 field to find matching records.

Parameters:
    $host_item_data - hashref containing:
        - title: title from 773$t
        - author: author from 773$a
        - isbn: ISBN from 773$z
        - issn: ISSN from 773$x

=cut

sub search_possible_hosts {
    my ($self, $host_item_data) = @_;
    
    return (undef, 0) unless $host_item_data;
    
    my @should_clauses;
    
    # Search by title from 773$t (host-item title)
    if ($host_item_data->{title}) {
        push @should_clauses, {
            match => {
                title => {
                    query => $host_item_data->{title},
                    boost => 3.0,
                }
            }
        };
        # Also try title-series field
        push @should_clauses, {
            match => {
                'title-series' => {
                    query => $host_item_data->{title},
                    boost => 2.5,
                }
            }
        };
    }
    
    # Search by author from 773$a
    if ($host_item_data->{author}) {
        push @should_clauses, {
            match => {
                author => {
                    query => $host_item_data->{author},
                    boost => 2.0,
                }
            }
        };
    }
    
    # Search by ISBN from 773$z
    if ($host_item_data->{isbn}) {
        push @should_clauses, {
            term => {
                'isbn' => {
                    value => $host_item_data->{isbn},
                    boost => 5.0,
                }
            }
        };
    }
    
    # Search by ISSN from 773$x
    if ($host_item_data->{issn}) {
        push @should_clauses, {
            term => {
                'issn' => {
                    value => $host_item_data->{issn},
                    boost => 5.0,
                }
            }
        };
    }
    
    return (undef, 0) unless @should_clauses;
    
    my $query = {
        query => {
            bool => {
                should => \@should_clauses,
                minimum_should_match => 1,
                must_not => [
                    # Exclude component parts - we're looking for hosts
                    { exists => { field => 'record-control-number-773w' } },
                ],
            },
        },
        # Sort by relevance score
        sort => ['_score'],
    };
    
    # Return more results for possible hosts (up to 10 potential matches)
    my ($results, $total) = $self->search_records_no_scroll($query, {size => 10});
    
    return ($results, $total);
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

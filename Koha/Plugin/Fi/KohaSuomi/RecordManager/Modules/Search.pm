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

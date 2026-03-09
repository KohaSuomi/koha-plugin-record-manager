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
                #next unless $cni =~ /^(FI-MELINDA|FI-BTJ|FI-TATI)$/;
                next unless $w;
                my ($control_number) = $w =~ /(\d+)/;
                my $cni_control_number = "($cni)$control_number";
                
                # Check if host record does not exist
                if ( !$self->host_record_exists($control_number, $cni_control_number) ) {
                    push @all_orphans, {
                        id => $component_id,
                        control_number => $control_number,
                        cni_control_number => $cni_control_number,
                        title => $component->{'title'}[0] || '',
                        'host-item' => $component->{'host-item'}[0] || '',
                        'record-control-number-773w' => $component->{'record-control-number-773w'}[0] || '',
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
    my ($scroll_id, $results, $total) = $search->search_host_records($control_number, $cni_control_number);
    
    # Return true (1) if host record exists (total > 0), false (0) otherwise
    return $total > 0 ? 1 : 0;
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

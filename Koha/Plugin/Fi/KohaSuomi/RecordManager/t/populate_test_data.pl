#!/usr/bin/perl

# Copyright 2026 KohaSuomi
#
# This script populates the database with host records and component parts
# for testing orphan record detection

use Modern::Perl;
use Getopt::Long;
use C4::Biblio;
use C4::Context;
use MARC::Record;
use MARC::Field;

=head1 NAME

populate_test_data.pl - Populate database with host and component part records

=head1 SYNOPSIS

    perl populate_test_data.pl [options]

=head1 OPTIONS

=over 4

=item B<--hosts=N>

Number of host records to create (default: 10)

=item B<--components=N>

Number of component parts per host (default: 3)

=item B<--orphans=N>

Number of orphan component parts to create (default: 5)

=item B<--verbose>

Print detailed output

=item B<--help>

Print this help message

=back

=head1 EXAMPLE

    # Create 10 hosts with 3 components each, plus 5 orphans
    perl populate_test_data.pl --hosts=10 --components=3 --orphans=5 --verbose

=head1 DESCRIPTION

This script creates:
- Host records (journals, books, proceedings)
- Component parts (articles, chapters) that correctly reference hosts
- Orphan component parts that reference non-existent hosts

=cut

my $num_hosts = 10;
my $num_components = 3;
my $num_orphans = 5;
my $verbose = 0;
my $help = 0;

GetOptions(
    'hosts=i'      => \$num_hosts,
    'components=i' => \$num_components,
    'orphans=i'    => \$num_orphans,
    'verbose'      => \$verbose,
    'help'         => \$help,
) or die "Error in command line arguments\n";

if ($help) {
    print_help();
    exit 0;
}

print "=" x 70 . "\n";
print "Populating Test Data for Record Manager\n";
print "=" x 70 . "\n";
print "Creating:\n";
print "  - $num_hosts host records\n";
print "  - $num_components component parts per host\n";
print "  - $num_orphans orphan component parts\n";
print "=" x 70 . "\n\n";

my @host_records;
my @component_records;
my @orphan_records;

# Array of CNI prefixes used in Finnish libraries
my @cni_prefixes = ('FI-MELINDA', 'FI-BTJ', 'FI-TATI');

# Host record types and titles
my @host_types = (
    { type => 'journal', titles => [
        'Journal of Library Science',
        'Nordic Library Quarterly',
        'Finnish Library Review',
        'Information Management Today',
        'Scandinavian Information Science',
        'European Archives Journal',
        'Cataloging & Classification Quarterly',
        'Public Library Review',
        'Technical Services Quarterly',
        'Library Resources & Technical Services',
    ]},
    { type => 'book', titles => [
        'Modern Cataloging Practices',
        'Digital Libraries Handbook',
        'Information Architecture Guide',
        'Library Management Principles',
        'Collection Development Strategies',
    ]},
    { type => 'proceedings', titles => [
        'Nordic Library Conference Proceedings',
        'International Cataloging Symposium',
        'Digital Preservation Summit',
        'Library Technology Forum',
        'Information Literacy Symposium',
    ]},
);

# Component part titles (articles, chapters)
my @component_titles = (
    'Artificial Intelligence in Modern Libraries',
    'Cataloging Best Practices for Digital Collections',
    'User Experience Design in Academic Libraries',
    'Metadata Standards and Interoperability',
    'Open Access Publishing Trends',
    'Digital Preservation Strategies',
    'Linked Data Applications in Cataloging',
    'Community Engagement through Public Libraries',
    'MARC Format Evolution and RDA Implementation',
    'Collection Development in the Digital Age',
    'Information Literacy Programs',
    'Cloud Computing Infrastructure for Libraries',
    'Accessibility Standards for Library Websites',
    'Interlibrary Loan Services Optimization',
    'Machine Learning for Library Systems',
    'Copyright Issues in Digital Libraries',
    'Mobile Applications for Library Services',
    'Discovery Systems and User Behavior',
    'Resource Sharing Network Implementation',
    'BIBFRAME Implementation Experiences',
);

my @authors = (
    'Virtanen, Anna',
    'Korhonen, Mikko',
    'Nieminen, Laura',
    'Mäkinen, Jari',
    'Lehtonen, Sari',
    'Koskinen, Petri',
    'Heikkinen, Maria',
    'Järvinen, Timo',
    'Rantanen, Kaisa',
    'Laaksonen, Ville',
);

print "Creating host records...\n";

# Create host records
for (my $i = 1; $i <= $num_hosts; $i++) {
    my $type_idx = int(rand(scalar @host_types));
    my $type_data = $host_types[$type_idx];
    my $title_idx = int(rand(scalar @{$type_data->{titles}}));
    my $title = $type_data->{titles}[$title_idx];
    
    my $cni = $cni_prefixes[int(rand(scalar @cni_prefixes))];
    my $control_number = 100000 + $i;
    
    my $marc = MARC::Record->new();
    $marc->encoding('UTF-8');
    $marc->leader('00000nas a2200000 a 4500');
    
    # Add control number (001)
    $marc->append_fields(
        MARC::Field->new('001', "($cni)$control_number"),
    );
    
    # Add basic fields
    if ($type_data->{type} eq 'journal') {
        # Journal - use 022 for ISSN, 260 for publication
        $marc->append_fields(
            MARC::Field->new('022', '', '', 'a' => sprintf("%04d-%04d", int(rand(9999)), int(rand(9999)))),
            MARC::Field->new('245', '0', '0', 'a' => $title),
            MARC::Field->new('260', '', '', 
                'a' => 'Helsinki :',
                'b' => 'Finnish Library Association,',
                'c' => (2020 + int(rand(6))) . '-',
            ),
        );
    } elsif ($type_data->{type} eq 'book') {
        # Book - use 020 for ISBN
        $marc->append_fields(
            MARC::Field->new('020', '', '', 'a' => sprintf("978-952-%04d-%03d-1", int(rand(9999)), int(rand(999)))),
            MARC::Field->new('100', '1', '', 'a' => $authors[int(rand(scalar @authors))]),
            MARC::Field->new('245', '1', '0', 'a' => $title),
            MARC::Field->new('260', '', '', 
                'a' => 'Helsinki :',
                'b' => 'Library Press,',
                'c' => (2020 + int(rand(6))) . '.',
            ),
        );
    } else {
        # Proceedings
        $marc->append_fields(
            MARC::Field->new('245', '1', '0', 'a' => $title),
            MARC::Field->new('260', '', '', 
                'a' => 'Helsinki :',
                'b' => 'Conference Organizers,',
                'c' => (2020 + int(rand(6))) . '.',
            ),
        );
    }
    
    my ($biblionumber, $biblioitemnumber) = C4::Biblio::AddBiblio($marc, '');
    
    push @host_records, {
        biblionumber => $biblionumber,
        control_number => $control_number,
        cni => $cni,
        cni_control_number => "($cni)$control_number",
        title => $title,
        type => $type_data->{type},
    };
    
    if ($verbose) {
        print "  Created host #$i: $title (biblionumber: $biblionumber, control: ($cni)$control_number)\n";
    }
}

print "Created " . scalar(@host_records) . " host records\n\n";

print "Creating component parts for each host...\n";

# Create component parts for each host
my $component_count = 0;
foreach my $host (@host_records) {
    for (my $j = 1; $j <= $num_components; $j++) {
        $component_count++;
        my $title_idx = int(rand(scalar @component_titles));
        my $title = $component_titles[$title_idx];
        
        my $component_control_number = 200000 + $component_count;
        
        my $marc = MARC::Record->new();
        $marc->encoding('UTF-8');
        $marc->leader('00000naa a2200000 a 4500');
        
        # Add control number for the component part
        $marc->append_fields(
            MARC::Field->new('001', "$component_control_number"),
            MARC::Field->new('003', $host->{cni}),
        );
        
        # Add author and title
        $marc->append_fields(
            MARC::Field->new('100', '1', '', 'a' => $authors[int(rand(scalar @authors))]),
            MARC::Field->new('245', '1', '0', 'a' => $title),
        );
        
        # Add 773 field linking to host
        my @subfields = (
            't' => $host->{title},
            'w' => $host->{cni_control_number},
        );
        
        # Add volume/issue info for journals
        if ($host->{type} eq 'journal') {
            push @subfields, 'g' => sprintf("Vol. %d, No. %d (%d), p. %d-%d", 
                int(rand(50)) + 1, 
                int(rand(4)) + 1, 
                2020 + int(rand(6)),
                int(rand(90)) + 10,
                int(rand(90)) + 110
            );
        } elsif ($host->{type} eq 'book') {
            push @subfields, 'g' => sprintf("p. %d-%d", int(rand(50)) + 10, int(rand(50)) + 60);
        }
        
        $marc->append_fields(
            MARC::Field->new('773', '0', '8', @subfields),
        );
        
        my ($biblionumber, $biblioitemnumber) = C4::Biblio::AddBiblio($marc, '');
        
        push @component_records, {
            biblionumber => $biblionumber,
            host_biblionumber => $host->{biblionumber},
            host_control => $host->{cni_control_number},
            title => $title,
        };
        
        if ($verbose) {
            print "  Created component #$component_count: $title -> $host->{title}\n";
        }
    }
}

print "Created " . scalar(@component_records) . " component part records\n\n";

print "Creating orphan component parts (no host)...\n";

# Create orphan component parts (references to non-existent hosts)
for (my $i = 1; $i <= $num_orphans; $i++) {
    my $title_idx = int(rand(scalar @component_titles));
    my $title = $component_titles[$title_idx];
    
    my $cni = $cni_prefixes[int(rand(scalar @cni_prefixes))];
    # Use control numbers that don't exist (999000+) - far from orphan's own 001 (800xxx)
    my $nonexistent_control = 999000 + $i;
    my $orphan_control = 800000 + $i;
    
    my $marc = MARC::Record->new();
    $marc->encoding('UTF-8');
    $marc->leader('00000naa a2200000 a 4500');
    
    # Add control number for the orphan itself
    $marc->append_fields(
        MARC::Field->new('001', "$orphan_control"),
        MARC::Field->new('003', $cni),
    );
    
    # Add author and title
    $marc->append_fields(
        MARC::Field->new('100', '1', '', 'a' => $authors[int(rand(scalar @authors))]),
        MARC::Field->new('245', '1', '0', 'a' => $title . " [ORPHAN]"),
    );
    
    # Add 773 field with non-existent host control number
    $marc->append_fields(
        MARC::Field->new('773', '0', '8',
            't' => "Non-existent Host Record $i",
            'w' => "($cni)$nonexistent_control",
            'g' => sprintf("Vol. %d (%d)", int(rand(50)) + 1, 2020 + int(rand(6))),
        ),
    );
    
    my ($biblionumber, $biblioitemnumber) = C4::Biblio::AddBiblio($marc, '');
    
    push @orphan_records, {
        biblionumber => $biblionumber,
        missing_control => "($cni)$nonexistent_control",
        title => $title,
    };
    
    if ($verbose) {
        print "  Created orphan #$i: $title [missing host: ($cni)$nonexistent_control]\n";
    }
}

print "Created " . scalar(@orphan_records) . " orphan records\n\n";

print "=" x 70 . "\n";
print "Summary:\n";
print "=" x 70 . "\n";
print "Host records:           " . scalar(@host_records) . "\n";
print "Component parts:        " . scalar(@component_records) . "\n";
print "Orphan components:      " . scalar(@orphan_records) . "\n";
print "Total records created:  " . (scalar(@host_records) + scalar(@component_records) + scalar(@orphan_records)) . "\n";
print "=" x 70 . "\n\n";

if ($verbose) {
    print "\nHost Records:\n";
    print "-" x 70 . "\n";
    foreach my $host (@host_records) {
        print sprintf("  [%d] %s (%s)\n", 
            $host->{biblionumber}, 
            $host->{title}, 
            $host->{cni_control_number}
        );
    }
    
    print "\nOrphan Records (for testing):\n";
    print "-" x 70 . "\n";
    foreach my $orphan (@orphan_records) {
        print sprintf("  [%d] %s -> missing [%s]\n", 
            $orphan->{biblionumber}, 
            $orphan->{title}, 
            $orphan->{missing_control}
        );
    }
    print "\n";
}

print "Done! You can now test orphan record detection.\n";
print "Orphan records should appear in the /records/orphans API endpoint.\n";

sub print_help {
    print <<'HELP';
populate_test_data.pl - Populate database with host and component part records

SYNOPSIS:
    perl populate_test_data.pl [options]

OPTIONS:
    --hosts=N       Number of host records to create (default: 10)
    --components=N  Number of component parts per host (default: 3)
    --orphans=N     Number of orphan component parts (default: 5)
    --verbose       Print detailed output
    --help          Show this help message

EXAMPLES:
    # Use defaults
    perl populate_test_data.pl

    # Create more test data
    perl populate_test_data.pl --hosts=20 --components=5 --orphans=10

    # Verbose output
    perl populate_test_data.pl --verbose

DESCRIPTION:
    This script creates test data for the Record Manager plugin:
    
    1. Host Records: Journal issues, books, conference proceedings
       - Each has a control number in 001 field
       - Can be referenced by component parts
    
    2. Component Parts: Articles, chapters, papers
       - Have MARC 773 field with $w pointing to host control number
       - Correctly link to existing host records
    
    3. Orphan Component Parts: Articles with missing hosts
       - Have MARC 773$w pointing to NON-EXISTENT control numbers
       - These should appear in the orphan records API
    
    The orphan records use control numbers 999000+ which don't exist,
    making them easy to identify in the orphan detection system.

HELP
}

1;

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

=item B<--broken-links=N>

Number of component parts with broken links to create per host (default: 2)

=item B<--verbose>

Print detailed output

=item B<--help>

Print this help message

=back

=head1 EXAMPLE

    # Create 10 hosts with 3 components each, plus 2 broken links per host
    perl populate_test_data.pl --hosts=10 --components=3 --broken-links=2 --verbose

=head1 DESCRIPTION

This script creates:
- Host records (journals, books, proceedings) with ISBN/ISSN
- Component parts (articles, chapters) that correctly reference hosts
- Component parts with BROKEN links - they have correct host metadata (title, author, ISBN/ISSN) 
  in the 773 field but WRONG control number in 773$w, so they can be found with find_possible_hosts

=cut

my $num_hosts = 10;
my $num_components = 3;
my $num_broken_links = 2;
my $verbose = 0;
my $help = 0;

GetOptions(
    'hosts=i'         => \$num_hosts,
    'components=i'    => \$num_components,
    'broken-links=i'  => \$num_broken_links,
    'verbose'         => \$verbose,
    'help'            => \$help,
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
print "  - $num_components component parts per host (valid links)\n";
print "  - $num_broken_links component parts per host (BROKEN links)\n";
print "=" x 70 . "\n\n";

my @host_records;
my @component_records;
my @broken_link_records;

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
    
    # Store ISBN/ISSN for later use in broken links
    my $isbn = sprintf("978-952-%04d-%03d-1", int(rand(9999)), int(rand(999)));
    my $issn = sprintf("%04d-%04d", int(rand(9999)), int(rand(9999)));
    my $author = $authors[int(rand(scalar @authors))];
    
    # Add basic fields
    if ($type_data->{type} eq 'journal') {
        # Journal - use 022 for ISSN, 260 for publication
        $marc->append_fields(
            MARC::Field->new('022', '', '', 'a' => $issn),
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
            MARC::Field->new('020', '', '', 'a' => $isbn),
            MARC::Field->new('100', '1', '', 'a' => $author),
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
            MARC::Field->new('100', '1', '', 'a' => $author),
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
        author => $author,
        isbn => $isbn,
        issn => $issn,
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
        my @subfields = ();
        
        # Add author only if host has one (books and proceedings, not journals)
        if ($host->{type} ne 'journal') {
            push @subfields, 'a' => $host->{author};  # Host author
        }
        
        # Always add title and control number
        push @subfields, 't' => $host->{title};   # Host title
        push @subfields, 'w' => $host->{cni_control_number};  # Control number
        
        # Add ISBN/ISSN for better matching
        if ($host->{type} eq 'journal') {
            push @subfields, 'x' => $host->{issn};  # ISSN
        } elsif ($host->{type} eq 'book') {
            push @subfields, 'z' => $host->{isbn};  # ISBN
        }
        
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

print "Creating component parts with BROKEN links (but host exists)...\n";

# Create component parts with broken control number links but correct metadata
# These should be findable using the find_possible_hosts endpoint
my $broken_count = 0;
foreach my $host (@host_records) {
    for (my $j = 1; $j <= $num_broken_links; $j++) {
        $broken_count++;
        my $title_idx = int(rand(scalar @component_titles));
        my $title = $component_titles[$title_idx];
        
        my $component_control_number = 300000 + $broken_count;
        
        # Use a WRONG control number (999000+) that doesn't exist
        my $wrong_control_number = 999000 + $broken_count;
        
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
            MARC::Field->new('245', '1', '0', 'a' => $title . " [BROKEN LINK]"),
        );
        
        # Add 773 field with WRONG control number but CORRECT metadata
        my @subfields = ();
        
        # Add author only if host has one (books and proceedings, not journals)
        if ($host->{type} ne 'journal') {
            push @subfields, 'a' => $host->{author};  # Correct author from host
        }
        
        # Always add title and control number
        push @subfields, 't' => $host->{title};   # Correct title from host
        push @subfields, 'w' => "($host->{cni})$wrong_control_number";  # WRONG control number!
        
        # Add ISBN/ISSN from host - this is what find_possible_hosts will use
        if ($host->{type} eq 'journal') {
            push @subfields, 'x' => $host->{issn};  # Correct ISSN
            push @subfields, 'g' => sprintf("Vol. %d, No. %d (%d), p. %d-%d", 
                int(rand(50)) + 1, 
                int(rand(4)) + 1, 
                2020 + int(rand(6)),
                int(rand(90)) + 10,
                int(rand(90)) + 110
            );
        } elsif ($host->{type} eq 'book') {
            push @subfields, 'z' => $host->{isbn};  # Correct ISBN
            push @subfields, 'g' => sprintf("p. %d-%d", int(rand(50)) + 10, int(rand(50)) + 60);
        }
        
        $marc->append_fields(
            MARC::Field->new('773', '0', '8', @subfields),
        );
        
        my ($biblionumber, $biblioitemnumber) = C4::Biblio::AddBiblio($marc, '');
        
        push @broken_link_records, {
            biblionumber => $biblionumber,
            host_biblionumber => $host->{biblionumber},
            wrong_control => "($host->{cni})$wrong_control_number",
            correct_control => $host->{cni_control_number},
            title => $title,
            host_title => $host->{title},
        };
        
        if ($verbose) {
            print "  Created broken link #$broken_count: $title\n";
            print "    -> Wrong control: ($host->{cni})$wrong_control_number\n";
            print "    -> Correct host: $host->{title} [$host->{cni_control_number}]\n";
        }
    }
}

print "Created " . scalar(@broken_link_records) . " broken link records\n\n";

print "=" x 70 . "\n";
print "Summary:\n";
print "=" x 70 . "\n";
print "Host records:              " . scalar(@host_records) . "\n";
print "Component parts (valid):   " . scalar(@component_records) . "\n";
print "Component parts (broken):  " . scalar(@broken_link_records) . "\n";
print "Total records created:     " . (scalar(@host_records) + scalar(@component_records) + scalar(@broken_link_records)) . "\n";
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
        print sprintf("        ISBN: %s, ISSN: %s\n", $host->{isbn} || 'N/A', $host->{issn} || 'N/A');
    }
    
    print "\nBroken Link Records (for testing find_possible_hosts):\n";
    print "-" x 70 . "\n";
    foreach my $broken (@broken_link_records) {
        print sprintf("  [%d] %s\n", 
            $broken->{biblionumber}, 
            $broken->{title}
        );
        print sprintf("        Wrong 773\$w: %s\n", $broken->{wrong_control});
        print sprintf("        Actual host: [%d] %s (%s)\n", 
            $broken->{host_biblionumber},
            $broken->{host_title},
            $broken->{correct_control}
        );
    }
    print "\n";
}

print "Done! You can now test the find_possible_hosts functionality.\n";
print "Broken link records should appear in /records/orphans endpoint.\n";
print "Use /records/{biblionumber}/possible-hosts to find the correct host.\n";

sub print_help {
    print <<'HELP';
populate_test_data.pl - Populate database with host and component part records

SYNOPSIS:
    perl populate_test_data.pl [options]

OPTIONS:
    --hosts=N         Number of host records to create (default: 10)
    --components=N    Number of component parts per host with valid links (default: 3)
    --broken-links=N  Number of component parts per host with broken links (default: 2)
    --verbose         Print detailed output
    --help            Show this help message

EXAMPLES:
    # Use defaults
    perl populate_test_data.pl

    # Create more test data
    perl populate_test_data.pl --hosts=20 --components=5 --broken-links=3

    # Verbose output
    perl populate_test_data.pl --verbose

DESCRIPTION:
    This script creates test data for the Record Manager plugin:
    
    1. Host Records: Journal issues, books, conference proceedings
       - Each has a control number in 001 field
       - Include ISBN (for books) and ISSN (for journals)
       - Can be referenced by component parts
    
    2. Component Parts (Valid): Articles, chapters, papers
       - Have MARC 773 field with $w pointing to host control number
       - Correctly link to existing host records
    
    3. Component Parts (Broken Links): Articles with incorrect control numbers
       - Have MARC 773 field with WRONG control number in $w (999000+)
       - BUT have CORRECT metadata: title, author, ISBN/ISSN in other subfields
       - The actual host record EXISTS in the database
       - These test the find_possible_hosts functionality
    
    The broken link records can be found in /records/orphans endpoint.
    Use /records/{biblionumber}/possible-hosts to find the correct host
    by searching with the metadata from the 773 field.

HELP
}

1;

package Slic3r::Electronics::Filereaders::Eagle;
use strict;
use warnings;
use utf8;

use XML::LibXML;
use Slic3r::Electronics::ElectronicPart;

#######################################################################
# Purpose    : Reads file of the Eagle type
# Parameters : Filename to read
# Returns    : Schematic of electronics
# Commet     : 
#######################################################################
sub readFile {
    my $self = shift;
    my ($filename) = @_;

    my $parser = XML::LibXML->new();
    my $xmldoc = $parser->parse_file($filename);
    
    my @partlist = ();

    for my $sheet ($xmldoc->findnodes('/eagle/drawing/schematic/sheets/sheet')) {
        for my $instance ($sheet->findnodes('./instances/instance')) {
            my $part = $instance->getAttribute('part');
            for my $partlist ($xmldoc->findnodes("/eagle/drawing/schematic/parts/part[\@name='$part']")) {
                my $library = $partlist->getAttribute('library');
                my $deviceset = $partlist->getAttribute('deviceset');
                my $device = $partlist->getAttribute('device');
                for my $devicesetlist ($xmldoc->findnodes("/eagle/drawing/schematic/libraries/library[\@name='$library']/devicesets/deviceset[\@name='$deviceset']/devices/device[\@name='$device']")) {
                    my $package = $devicesetlist->getAttribute('package');
                    if (defined $package) {
                        my $newpart = Slic3r::Electronics::ElectronicPart->new(
                            $part,
                            $library,
                            $deviceset,
                            $device,
                            $package,
                        );
                        for my $packagelist ($xmldoc->findnodes("/eagle/drawing/schematic/libraries/library[\@name='$library']/packages/package[\@name='$package']/smd")) {
                            my $shape = $packagelist->getAttribute('shape');
                            my $rotation = $packagelist->getAttribute('rot');
                            if (! (defined $shape)) {
                                $shape = 'none';
                            }
                            if (defined $rotation) {
                                $rotation =~ s/R//;
                            } else {
                                $rotation = 0;
                            }
                            $newpart->addPad(
                                $packagelist->getName,
                                $packagelist->getAttribute('name'),
                                $packagelist->getAttribute('x'),
                                $packagelist->getAttribute('y'),
                                $rotation,
                                $packagelist->getAttribute('dx'),
                                $packagelist->getAttribute('dy'),
                                0,
                                $shape,
                            );
                        }
                        for my $packagelist ($xmldoc->findnodes("/eagle/drawing/schematic/libraries/library[\@name='$library']/packages/package[\@name='$package']/pad")) {
                            my $shape = $packagelist->getAttribute('shape');
                            my $rotation = $packagelist->getAttribute('rot');
                            if (! (defined $shape)) {
                                $shape = 'none';
                            }
                            if (defined $rotation) {
                                $rotation =~ s/R//;
                            } else {
                                $rotation = 0;
                            }
                            $newpart->addPad(
                                $packagelist->getName,
                                $packagelist->getAttribute('name'),
                                $packagelist->getAttribute('x'),
                                $packagelist->getAttribute('y'),
                                $rotation,
                                0,
                                0,
                                $packagelist->getAttribute('drill'),
                                $shape,
                            );
                        }
                        push @partlist, $newpart;
                    } else {
                        print $part, " has no package assigned.\n";
                    }
                }
            }
        }
    }
    return @partlist;
}

1;
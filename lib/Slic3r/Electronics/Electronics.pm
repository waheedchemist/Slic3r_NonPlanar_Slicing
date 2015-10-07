#!/usr/bin/perl

package Slic3r::Electronics::Electronics;
use strict;
use warnings;
use utf8;

sub readFile {
    my $self = shift;
    my ($filename) = @_;
    
    open my $file, $filename or die "Could not open $filename: $!"; 
    my $firstLine = <$file>; 
    my $secondLine = <$file>;
    close $file;

    if (index($secondLine, 'eagle') != -1) {
        my @schematic =  Slic3r::Electronics::ReadEagle->readXML($filename);
        return @schematic;
    }
    
    return ;
}




package Slic3r::Electronics::ReadEagle;
use strict;
use warnings;
use utf8;

use XML::LibXML;

sub readXML {
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

package Slic3r::Electronics::ElectronicPart;
use strict;
use warnings;
use utf8;

sub new {
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    my ($name,$library,$deviceset,$device,$package) = @_;
    $self->{name} = $name;
    $self->{library} = $library;
    $self->{deviceset} = $deviceset;
    $self->{device} = $device;
    $self->{package} = $package;
    
    my @position = @{$self->{position}} = (0,0,0);
    my @rotation = @{$self->{rotation}} = (0,0,0);
    
    my @padlist = @{$self->{padlist}} = ();
    
    return $self;
}

sub setPosition {
    my $self = shift;
    my ($x,$y,$z) = @_;
    @{$self->{position}} = ($x,$y,$z);
}

sub setRotation {
    my $self = shift;
    my ($r,$p,$y) = @_;
    @{$self->{rotation}} = ($r,$p,$y);
}

sub addPad {
    my $self = shift;
    my $pad = Slic3r::Electronics::ElectronicPad->new(@_);
    push @{$self->{padlist}}, $pad;
}

package Slic3r::Electronics::ElectronicPad;
use strict;
use warnings;
use utf8;

sub new {
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    my ($type,$name,$x,$y,$r,$dx,$dy,$drill,$shape) = @_;
    $self->{type} = $type;
    $self->{name} = $name;
    $self->{drill} = $drill;
    $self->{shape} = $shape;
    
    my @position = @{$self->{position}} = ($x,$y,0);
    my @size = @{$self->{size}} = ($dx,$dy,0);
    my @rotation = @{$self->{rotation}} = (0,0,$r);
    
    return $self
}

sub setPosition {
    my $self = shift;
    my ($x,$y,$z) = @_;
    @{$self->{position}} = ($x,$y,$z);
}

sub setRotation {
    my $self = shift;
    my ($r,$p,$y) = @_;
    @{$self->{rotation}} = ($r,$p,$y);
}

1;
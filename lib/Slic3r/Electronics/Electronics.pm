#!/usr/bin/perl

package Slic3r::Electronics::Electronics;
use strict;
use warnings;
use utf8;

use File::Basename;
use Slic3r::Electronics::Filereaders::Eagle;
use Slic3r::Electronics::Filereaders::3DElectronics;

sub readFile {
    my $self = shift;
    my ($filename) = @_;
    
    my ($base,$path,$type) = fileparse($filename,('.sch','.SCH','3de','.3DE'));
    my @schematic;
    if ($type eq "sch" || $type eq "SCH" || $type eq ".sch" || $type eq ".SCH") {
        @schematic = Slic3r::Electronics::Filereaders::Eagle->readFile($filename);
        return ($filename, @schematic);
    } elsif ($type eq "3de" || $type eq "3DE" || $type eq ".3de" || $type eq ".3DE") {
        ($filename, @schematic) = Slic3r::Electronics::Filereaders::3DElectronics->readFile($filename);
        return ($filename, @schematic);
    }
    
    return ;
}

sub writeFile {
    my $self = shift;
    my ($filename, @schematic) = @_;
    return Slic3r::Electronics::Filereaders::3DElectronics->writeFile($filename, @schematic);
}

1;
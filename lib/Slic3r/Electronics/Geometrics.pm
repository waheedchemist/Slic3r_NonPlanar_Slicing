package Slic3r::Electronics::Geometrics;
use strict;
use warnings;
use utf8;

sub getCube {
    my $self = shift;
    my ($x,$y,$z,$dx,$dy,$dz) = @_;
    $x -= $dx/2;
    $y -= $dy/2;
    my @triangles = ();
    push @triangles, $self->getSquare($x,     $y,     $z,     $dx, $dy, 0); #down
    push @triangles, $self->getSquare($x,     $y,     $z,     0,   $dy, $dz); #left
    push @triangles, $self->getSquare($x,     $y+$dy, $z,     $dx, 0,   $dz); #back
    push @triangles, $self->getSquare($x+$dx, $y,     $z,     0,   $dy, $dz); #right
    push @triangles, $self->getSquare($x    , $y,     $z,     $dx, 0,   $dz); #front
    push @triangles, $self->getSquare($x    , $y,     $z+$dz, $dx, $dy, 0); #top
    return @triangles;
    
}

sub getSquare {
    my $self = shift;
    my ($x,$y,$z,$dx,$dy,$dz) = @_;
    my @square = ();
    push @square, [[$x, $y, $z], [$x, $y+$dy, $z+$dz], [$x+$dx, $y+$dy, $z]];
    push @square, [[$x, $y, $z], [$x+$dx, $y+$dy, $z], [$x+$dx, $y, $z+$dz]];
    return @square;   
}

1;
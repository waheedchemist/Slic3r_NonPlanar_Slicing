package Slic3r::Electronics::ElectronicPart;
use strict;
use warnings;
use utf8;

use Slic3r::Electronics::Geometrics;

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
    $self->{height} = undef;
    my $volume = $self->{volume} = ();
    
    my @position = @{$self->{position}} = (undef,undef,undef);
    my @rotation = @{$self->{rotation}} = (0,0,0);
    
    my @padlist = @{$self->{padlist}} = ();
    
    return $self;
}

sub removePart {
    my $self = shift;
    $self->{volume} = undef;    
}

sub setPosition {
    my $self = shift;
    my ($x,$y,$z) = @_;
    $self->{position} = [$x,$y,$z];
}

sub setRotation {
    my $self = shift;
    my ($r,$p,$y) = @_;
    $self->{rotation} = [$r,$p,$y];
}

sub addPad {
    my $self = shift;
    my $pad = Slic3r::Electronics::ElectronicPad->new(@_);
    push @{$self->{padlist}}, $pad;
}

sub getModel {
    my $self = shift;
    my @triangles = ();
    for my $pad (@{$self->{padlist}}) {
        if ($pad->{type} eq 'smd') {
            push @triangles, Slic3r::Electronics::Geometrics->getCube(@{$pad->{position}}, ($pad->{size}[0], $pad->{size}[1], $self->{height}*(-1)));
        }
        if ($pad->{type} eq 'pad') {
            #TODO round hole pads
            push @triangles, Slic3r::Electronics::Geometrics->getCube(@{$pad->{position}}, @{$pad->{size}});
        }
    }
    my $model = $self->getTriangleMesh(@triangles);
    $model->translate(@{$self->{position}});
    return $model;
}

sub getTriangleMesh {
    my $self = shift;
    my (@triangles) = @_;
    my $vertices = $self->{vertices} = [];
    my $facets = $self->{facets} = [];
    for my $triangle (@triangles) {
        my @newTriangle = ();
        for my $point (@$triangle) {
            push @newTriangle, $self->getVertexID(@$point);
        }
        push @{$self->{facets}}, [@newTriangle];
    }
    
    my $mesh = Slic3r::TriangleMesh->new;
    $mesh->ReadFromPerl($self->{vertices}, $self->{facets});
    $mesh->repair;
    
    my $model = Slic3r::Model->new;
    
    my $object = $model->add_object(name => $self->{name});
    my $volume = $object->add_volume(mesh => $mesh, name => $self->{name});
    
    return $model;
}

sub getVertexID {
    my $self = shift;
    my @vertex = @_;
    my $id = 0;
    while ($id < scalar @{$self->{vertices}}) {
        if ( ${$self->{vertices}}[$id][0] == $vertex[0] && ${$self->{vertices}}[$id][1] == $vertex[1] && ${$self->{vertices}}[$id][2] == $vertex[2]) {;
            return $id;
        }
        $id += 1;
    }
    push (@{$self->{vertices}}, [@vertex]);
    return $id;
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

1;
package Slic3r::Electronics::ElectronicPart;
use strict;
use warnings;
use utf8;

use Slic3r::Electronics::Geometrics;
use Slic3r::Geometry qw(X Y Z deg2rad);
use List::Util qw[min max];

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
    $self->{volume} = undef;
    $self->{chipVolume} = undef;
    
    my @position = @{$self->{position}} = (undef,undef,undef);
    my @rotation = @{$self->{rotation}} = (0,0,0);
    
    my @padlist = @{$self->{padlist}} = ();
    
    my @chipsize = @{$self->{chipsize}} = (undef,undef,undef);

    return $self;
}

sub removePart {
    my $self = shift;
    $self->{volume} = undef; 
    $self->{chipVolume} = undef; 
    @{$self->{position}} = (undef,undef,undef);
    @{$self->{rotation}} = (0,0,0);
}

sub setPosition {
    my $self = shift;
    my ($x,$y,$z) = @_;
    $self->{position} = [$x,$y,$z];
}

sub setRotation {
    my $self = shift;
    my ($x,$y,$z) = @_;
    $self->{rotation} = [$x,$y,$z];
}

sub setChipsize {
    my $self = shift;
    my ($x,$y,$z) = @_;
    $self->{chipsize} = [$x,$y,$z];
}

sub getChipsize {
    my $self = shift;
    if (!(defined($self->{chipsize}[0]) && defined($self->{chipsize}[0]) && defined($self->{chipsize}[0]))) {
        my $xmin = 0;
        my $ymin = 0;
        my $xmax = 0;
        my $ymax = 0;
        for my $pad (@{$self->{padlist}}) {
            if ($pad->{type} eq 'smd') {
                $xmin = min($xmin, $pad->{position}[0]-$pad->{size}[0]/2);
                $xmax = max($xmax, $pad->{position}[0]+$pad->{size}[0]/2);
                $ymin = min($ymin, $pad->{position}[1]-$pad->{size}[1]/2);
                $ymax = max($ymax, $pad->{position}[1]+$pad->{size}[1]/2);
            }
            if ($pad->{type} eq 'pad') {
                $xmin = min($xmin, $pad->{position}[0]-($pad->{drill}/2+0.25));
                $xmax = max($xmax, $pad->{position}[0]+($pad->{drill}/2+0.25));
                $ymin = min($ymin, $pad->{position}[1]-($pad->{drill}/2+0.25));
                $ymax = max($ymax, $pad->{position}[1]+($pad->{drill}/2+0.25));
            }
        }
        @{$self->{chipsize}} = ($xmax-$xmin,$ymax-$ymin,$self->getChipheight);
    }
    
    return @{$self->{chipsize}};
}

sub getChipheight {
    my $self = shift;
    return 1;
}

sub addPad {
    my $self = shift;
    my $pad = Slic3r::Electronics::ElectronicPad->new(@_);
    push @{$self->{padlist}}, $pad;
}

sub getFootprintModel {
    my $self = shift;
    my @triangles = ();
    for my $pad (@{$self->{padlist}}) {
        if ($pad->{type} eq 'smd') {
            push @triangles, Slic3r::Electronics::Geometrics->getCube(@{$pad->{position}}, ($pad->{size}[0], $pad->{size}[1], $self->{height}*(-1)));
        }
        if ($pad->{type} eq 'pad') {
            #TODO round hole pads
            push @triangles, Slic3r::Electronics::Geometrics->getCylinder(@{$pad->{position}}, $pad->{drill}/2+0.25, $self->{height}*(-1));
        }
    }
    my $model = $self->getTriangleMesh(@triangles);
    return $model;
}

sub getChipModel {
    my $self = shift;
    my @triangles = ();
    push @triangles, Slic3r::Electronics::Geometrics->getCube((0,0,0), $self->getChipsize);
    my $model = $self->getTriangleMesh(@triangles);
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
    $mesh->rotate_x(deg2rad($self->{rotation}[0])) if ($self->{rotation}[0] != 0);
    $mesh->rotate_y(deg2rad($self->{rotation}[1])) if ($self->{rotation}[1] != 0);
    $mesh->rotate_z(deg2rad($self->{rotation}[2])) if ($self->{rotation}[2] != 0);
    $mesh->translate(@{$self->{position}});
    
    
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
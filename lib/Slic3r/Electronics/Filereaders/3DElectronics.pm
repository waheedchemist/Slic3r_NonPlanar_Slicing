package Slic3r::Electronics::Filereaders::3DElectronics;
use strict;
use warnings;
use utf8;

use XML::LibXML;
use File::Basename;
use Slic3r::Electronics::ElectronicPart;

sub readFile {
    my $self = shift;
    my ($filename) = @_;

    my $parser = XML::LibXML->new();
    my $xmldoc = $parser->parse_file($filename);
    my ($base,$path,$type) = fileparse($filename,('.sch','.SCH','3de','.3DE'));
    
    my @partlist = ();
    my $oldFilename;
    for my $files ($xmldoc->findnodes('/electronics/filename')) {
        $oldFilename = $files->getAttribute('source');
        ($oldFilename, @partlist) = Slic3r::Electronics::Electronics->readFile($path . $oldFilename);
    }
    for my $node ($xmldoc->findnodes('/electronics/parts/part')) {
        my $name = $node->getAttribute('name');
        my $library = $node->getAttribute('library');
        my $deviceset = $node->getAttribute('deviceset');
        my $device = $node->getAttribute('device');
        my $package = $node->getAttribute('package');
        my $height = undef;
        my @position = undef;
        my @rotation = undef;
        for my $h ($node->findnodes('./attributes')) {
            $height = $h->getAttribute('height');
        }
        for my $pos ($node->findnodes('./position')) {
            @position = ($pos->getAttribute('X'),$pos->getAttribute('Y'),$pos->getAttribute('Z'));
        }
        for my $rot ($node->findnodes('./rotation')) {
            @rotation = ($rot->getAttribute('roll'),$rot->getAttribute('pitch'),$rot->getAttribute('yaw'));
        }
        for my $part (@partlist) {
            if (($part->{name} eq $name) && 
                    ($part->{library} eq $library) && 
                    ($part->{deviceset} eq $deviceset) && 
                    ($part->{device} eq $device) && 
                    ($part->{package} eq $package)) {
                $part->{height} = $height;
                @{$part->{position}} = @position;
                @{$part->{rotation}} = @rotation;
            }
        }
    }
    return ($oldFilename, @partlist);

}

sub writeFile {
    my $self = shift;
    my ($filename, @schematics) = @_;
    my $dom = XML::LibXML::Document->createDocument('1.0','utf-8');
    my $root = $dom->createElement('electronics');
    $root->addChild($dom->createAttribute( version => '1.0'));
    $dom->setDocumentElement($root);
    
    my $file = $dom->createElement('filename');
    $root->addChild($file);
    $file->addChild($dom->createAttribute( source => basename($filename)));
    
    my $parts = $dom->createElement('parts');
    $root->addChild($parts);
    for my $part (@schematics) {
        if (defined($part->{position}[0]) && defined($part->{position}[1]) && defined($part->{position}[2])){
            my $node = $dom->createElement('part');
            $parts->addChild($node);
            $node->addChild($dom->createAttribute( name => $part->{name}));
            $node->addChild($dom->createAttribute( library => $part->{library}));
            $node->addChild($dom->createAttribute( deviceset => $part->{deviceset}));
            $node->addChild($dom->createAttribute( device => $part->{device}));
            $node->addChild($dom->createAttribute( package => $part->{package}));
            
            my $height = $dom->createElement('attributes');
            $node->addChild($height);
            $height->addChild($dom->createAttribute( height => $part->{height}));
            
            my $pos = $dom->createElement('position');
            $node->addChild($pos);
            $pos->addChild($dom->createAttribute( X => $part->{position}[0]));
            $pos->addChild($dom->createAttribute( Y => $part->{position}[1]));
            $pos->addChild($dom->createAttribute( Z => $part->{position}[2]));
            
            my $rot = $dom->createElement('rotation');
            $node->addChild($rot);
            $rot->addChild($dom->createAttribute( roll => $part->{rotation}[0]));
            $rot->addChild($dom->createAttribute( pitch => $part->{rotation}[1]));
            $rot->addChild($dom->createAttribute( yaw => $part->{rotation}[2]));
        }
    }
    my ($base,$path,$type) = fileparse($filename,('.sch','.SCH','3de','.3DE'));
    my $newpath = $path . $base . ".3de";
    return $dom->toFile($newpath, 0);
}

1;
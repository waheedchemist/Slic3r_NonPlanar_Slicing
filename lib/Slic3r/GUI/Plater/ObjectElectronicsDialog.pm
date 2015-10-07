package Slic3r::GUI::Plater::ObjectElectronicsDialog;
use strict;
use warnings;
use utf8;

use Wx qw(:dialog :id :misc :sizer :systemsettings :notebook wxTAB_TRAVERSAL);
use Wx::Event qw(EVT_BUTTON);
use base 'Wx::Frame';

sub new {
    my $class = shift;
    my ($parent, $print, %params) = @_;
    my $self = $class->SUPER::new($parent, -1, "3D Electronics for " . $params{object}->name, wxDefaultPosition, [800,600], &Wx::wxMAXIMIZE | &Wx::wxDEFAULT_FRAME_STYLE);
    $self->{$_} = $params{$_} for keys %params;
    
    $self->{tabpanel} = Wx::Notebook->new($self, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP | wxTAB_TRAVERSAL);
    $self->{tabpanel}->AddPage($self->{parts} = Slic3r::GUI::Plater::ElectronicsPanel->new($self->{tabpanel},$print, model_object => $params{model_object}), "Electronics");
        
    my $sizer = Wx::BoxSizer->new(wxVERTICAL);
    $sizer->Add($self->{tabpanel}, 1, wxEXPAND | wxTOP | wxLEFT | wxRIGHT, 10);
    
    $self->SetSizer($sizer);
    $self->SetMinSize($self->GetSize);
    
    return $self;
}


package Slic3r::GUI::Plater::ElectronicsPanel;
use strict;
use warnings;
use utf8;

use Slic3r::Print::State ':steps';
use File::Basename qw(basename);
use Wx qw(:misc :sizer :slider :treectrl :button :filedialog wxTAB_TRAVERSAL wxSUNKEN_BORDER wxBITMAP_TYPE_PNG wxFD_OPEN wxFD_FILE_MUST_EXIST wxID_OK
    wxTheApp);
use Wx::Event qw(EVT_BUTTON EVT_TREE_ITEM_COLLAPSING EVT_TREE_SEL_CHANGED EVT_SLIDER);
use Slic3r::Electronics::Electronics;
use base qw(Wx::Panel Class::Accessor);


__PACKAGE__->mk_accessors(qw(print enabled _loaded canvas slider));

use constant ICON_OBJECT        => 0;
use constant ICON_SOLIDMESH     => 1;
use constant ICON_MODIFIERMESH  => 2;
use constant ICON_PCB           => 3;

sub new {
    my $class = shift;
    my ($parent, $print, %params) = @_;
    my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL);
    
    my $object = $self->{model_object} = $params{model_object};
    my @schematic = @{$self->{schematic}} = ();
    
    # upper buttons
    my $btn_load_netlist = $self->{btn_load_netlist} = Wx::Button->new($self, -1, "Load netlist", wxDefaultPosition, wxDefaultSize, wxBU_LEFT);
    
    # upper buttons sizer
    my $buttons_sizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $buttons_sizer->Add($btn_load_netlist, 0);
    $btn_load_netlist->SetFont($Slic3r::GUI::small_font);
    
    
    # create TreeCtrl
    my $tree = $self->{tree} = Wx::TreeCtrl->new($self, -1, wxDefaultPosition, [300, 400], 
        wxTR_NO_BUTTONS | wxSUNKEN_BORDER | wxTR_HAS_VARIABLE_ROW_HEIGHT
        | wxTR_SINGLE | wxTR_NO_BUTTONS);
    {
        $self->{tree_icons} = Wx::ImageList->new(16, 16, 1);
        $tree->AssignImageList($self->{tree_icons});
        $self->{tree_icons}->Add(Wx::Bitmap->new("$Slic3r::var/brick.png", wxBITMAP_TYPE_PNG));     # ICON_OBJECT
        $self->{tree_icons}->Add(Wx::Bitmap->new("$Slic3r::var/package.png", wxBITMAP_TYPE_PNG));   # ICON_SOLIDMESH
        $self->{tree_icons}->Add(Wx::Bitmap->new("$Slic3r::var/plugin.png", wxBITMAP_TYPE_PNG));    # ICON_MODIFIERMESH
        $self->{tree_icons}->Add(Wx::Bitmap->new("$Slic3r::var/PCB-icon.png", wxBITMAP_TYPE_PNG));  # ICON_PCB
        
        my $rootId = $tree->AddRoot("Object", ICON_OBJECT);
        $tree->SetPlData($rootId, { type => 'object' });
    }
    
    # lower buttons
    my $btn_save_netlist = $self->{btn_save_netlist} = Wx::Button->new($self, -1, "Save netlist", wxDefaultPosition, wxDefaultSize, wxBU_LEFT);
    my $btn_export_stl = $self->{btn_export_stl} = Wx::Button->new($self, -1, "Export STL", wxDefaultPosition, wxDefaultSize, wxBU_LEFT);
    
    # lower buttons sizer
    my $buttons_sizer_bottom = Wx::BoxSizer->new(wxHORIZONTAL);
    $buttons_sizer_bottom->Add($btn_save_netlist, 0);
    $buttons_sizer_bottom->Add($btn_export_stl, 0);
    $btn_save_netlist->SetFont($Slic3r::GUI::small_font);
    $btn_export_stl->SetFont($Slic3r::GUI::small_font);
   
    # left pane with tree
    my $left_sizer = Wx::BoxSizer->new(wxVERTICAL);
    $left_sizer->Add($buttons_sizer, 0, wxEXPAND | wxLEFT | wxRIGHT | wxBOTTOM, 10);
    $left_sizer->Add($tree, 0, wxEXPAND | wxLEFT | wxRIGHT | wxBOTTOM, 10);
    $left_sizer->Add($buttons_sizer_bottom, 0, wxEXPAND | wxLEFT | wxRIGHT | wxBOTTOM, 10);
    
    # slider for choosing layer
    my $slider = $self->{slider} = Wx::Slider->new(
        $self, -1,
        0,                              # default
        0,                              # min
        # we set max to a bogus non-zero value because the MSW implementation of wxSlider
        # will skip drawing the slider if max <= min:
        1,                              # max
        wxDefaultPosition,
        wxDefaultSize,
        wxVERTICAL | &Wx::wxSL_INVERSE,
    );
    
    # label for slider
    my $z_label = $self->{z_label} = Wx::StaticText->new($self, -1, "", wxDefaultPosition, [40,-1], wxALIGN_CENTRE_HORIZONTAL);
    $z_label->SetFont($Slic3r::GUI::small_font);
    
    # slider sizer
    my $vsizer = Wx::BoxSizer->new(wxVERTICAL);
    $vsizer->Add($slider, 1, wxALL | wxEXPAND | wxALIGN_CENTER, 3);
    $vsizer->Add($z_label, 0, wxALL | wxEXPAND | wxALIGN_CENTER, 3);
    
    # right pane with preview canvas
    my $canvas;
    if ($Slic3r::GUI::have_OpenGL) {
        $canvas = $self->{canvas} = Slic3r::GUI::3DScene->new($self);
        $canvas->enable_picking(1);
        $canvas->select_by('volume');
                
        $canvas->load_object($self->{model_object}, undef, [0]);
        $canvas->set_auto_bed_shape;
        $canvas->SetSize([500,500]);
        $canvas->zoom_to_volumes;
        # init canvas
        $self->print($print);
        $self->reload_print;
    }
    
    #set box sizer
    $self->{sizer} = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->{sizer}->Add($left_sizer, 0, wxEXPAND | wxALL , 0);
    $self->{sizer}->Add($canvas, 1, wxEXPAND | wxALL, 1) if $canvas;
    $self->{sizer}->Add($vsizer, 0, wxTOP | wxBOTTOM | wxEXPAND, 5);
    
    $self->SetSizer($self->{sizer});
    $self->{sizer}->SetSizeHints($self);
    
    # attach events
    EVT_SLIDER($self, $slider, sub {
        $self->set_z($self->{layers_z}[$slider->GetValue])
            if $self->enabled;
    });

    
    EVT_TREE_ITEM_COLLAPSING($self, $tree, sub {
        my ($self, $event) = @_;
        $event->Veto;
    });
    
    EVT_TREE_SEL_CHANGED($self, $tree, sub {
        my ($self, $event) = @_;
        return if $self->{disable_tree_sel_changed_event};
        $self->selection_changed;
    });
    
    EVT_BUTTON($self, $self->{btn_load_netlist}, sub { 
        $self->LoadButtenPressed;
    });
    
    EVT_BUTTON($self, $self->{btn_save_netlist}, sub { 
        $self->SaveButtenPressed;
    });
    
    EVT_BUTTON($self, $self->{btn_export_stl}, sub { 
        $self->ExportButtenPressed; 
    });
    
    $self->reload_tree;
    
    return $self;
}

#reloads the print if something has changed
sub reload_print {
    my ($self) = @_;
    
    $self->canvas->reset_objects;
    $self->_loaded(0);
    $self->load_print;
}

# load the print
sub load_print {
    my ($self) = @_;
    return if $self->_loaded;
    
    # we require that there's at least one object and the posSlice step
    # is performed on all of them (this ensures that _shifted_copies was
    # populated and we know the number of layers)
    if (!$self->print->object_step_done(STEP_SLICE)) {
        $self->enabled(0);
        $self->{slider}->Hide;
        $self->canvas->Refresh;  # clears canvas
        return;
    }
    
    # configure slider
    {
        my %z = ();  # z => 1
        foreach my $object (@{$self->{print}->objects}) {
            foreach my $layer (@{$object->layers}, @{$object->support_layers}) {
                $z{$layer->print_z} = 1;
            }
        }
        $self->enabled(1);
        $self->{layers_z} = [ sort { $a <=> $b } keys %z ];
        $self->{slider}->SetRange(0, scalar(@{$self->{layers_z}})-1);
        if ((my $z_idx = $self->{slider}->GetValue) <= $#{$self->{layers_z}} && $self->{slider}->GetValue != 0) {
            $self->set_z($self->{layers_z}[$z_idx]);
        } else {
            $self->{slider}->SetValue(scalar(@{$self->{layers_z}})-1);
            $self->set_z($self->{layers_z}[-1]) if @{$self->{layers_z}};
        }
        $self->{slider}->Show;
        $self->Layout;
    }
    
    # load objects
    if ($self->IsShown) {
        # load skirt and brim
        $self->canvas->load_print_toolpaths($self->print);
        
        foreach my $object (@{$self->print->objects}) {
            $self->canvas->load_print_object_toolpaths($object);
            
        }
        
        #foreach my $object (@{$self->print->objects}) {
        #    $self->canvas->load_object($self->{model_object}, undef, [0]);
        #    
        #}
        
        $self->canvas->zoom_to_volumes;
        $self->_loaded(1);
    }
}

# set the z axis to the choosen slice
sub set_z {
    my ($self, $z) = @_;
    
    return if !$self->enabled;
    $self->{z_label}->SetLabel(sprintf '%.2f', $z);
    $self->canvas->set_toolpaths_range(0, $z);
    $self->canvas->Refresh if $self->IsShown;
}

# reloads the model tree
sub reload_tree {
    my ($self, $selected_volume_idx) = @_;
    
    $selected_volume_idx //= -1;
    my $object  = $self->{model_object};
    my $tree    = $self->{tree};
    my $rootId  = $tree->GetRootItem;
    
    # despite wxWidgets states that DeleteChildren "will not generate any events unlike Delete() method",
    # the MSW implementation of DeleteChildren actually calls Delete() for each item, so
    # EVT_TREE_SEL_CHANGED is being called, with bad effects (the event handler is called; this 
    # subroutine is never continued; an invisible EndModal is called on the dialog causing Plater
    # to continue its logic and rescheduling the background process etc. GH #2774)
    $self->{disable_tree_sel_changed_event} = 1;
    $tree->DeleteChildren($rootId);
    $self->{disable_tree_sel_changed_event} = 0;
    
    my $selectedId = $rootId;
    foreach my $volume_id (0..$#{$object->volumes}) {
        my $volume = $object->volumes->[$volume_id];
        
        my $icon = $volume->modifier ? ICON_MODIFIERMESH : ICON_SOLIDMESH;
        my $itemId = $tree->AppendItem($rootId, $volume->name || $volume_id, $icon);
        if ($volume_id == $selected_volume_idx) {
            $selectedId = $itemId;
        }
        $tree->SetPlData($itemId, {
            type        => 'volume',
            volume_id   => $volume_id,
        });
    }
    my $length = @{$self->{schematic}};
    if ($length > 0) {
        my $eIcon = ICON_PCB;
        my $eItemId = $tree->AppendItem($rootId, "Electronics", $eIcon);
        $tree->SetPlData($eItemId, {
            type        => 'volume',
            volume_id   => 0,
        });
        foreach my $part (@{$self->{schematic}}) {
            my $ItemId = $tree->AppendItem($eItemId, $part->{name}, $eIcon);
            $tree->SetPlData($ItemId, {
                type        => 'volume',
                volume_id   => 0,
            });
        }
    }
    $tree->ExpandAll;
    
    Slic3r::GUI->CallAfter(sub {
        $self->{tree}->SelectItem($selectedId);
        
        # SelectItem() should trigger EVT_TREE_SEL_CHANGED as per wxWidgets docs,
        # but in fact it doesn't if the given item is already selected (this happens
        # on first load)
        $self->selection_changed;
    });
}

# get the selected note from tree
sub get_selection {
    my ($self) = @_;
    
    my $nodeId = $self->{tree}->GetSelection;
    if ($nodeId->IsOk) {
        return $self->{tree}->GetPlData($nodeId);
    }
    return undef;
}

# tree selection changed event
sub selection_changed {
    my ($self) = @_;
    
    # deselect all meshes
    if ($self->{canvas}) {
        $_->selected(0) for @{$self->{canvas}->volumes};
    }

    
    if (my $itemData = $self->get_selection) {
        my ($config, @opt_keys);
        if ($itemData->{type} eq 'volume') {
            # select volume in 3D preview
            if ($self->{canvas}) {
                $self->{canvas}->volumes->[ $itemData->{volume_id} ]{selected} = 1;
            }
            #$self->{btn_delete}->Enable;
            
            # attach volume config to settings panel
            my $volume = $self->{model_object}->volumes->[ $itemData->{volume_id} ];
            $config = $volume->config;
            
            # get default values
            @opt_keys = @{Slic3r::Config::PrintRegion->new->get_keys};
        } elsif ($itemData->{type} eq 'object') {
            # select nothing in 3D preview
            
            # attach object config to settings panel
            @opt_keys = (map @{$_->get_keys}, Slic3r::Config::PrintObject->new, Slic3r::Config::PrintRegion->new);
            $config = $self->{model_object}->config;
        }
        # get default values
        my $default_config = Slic3r::Config->new_from_defaults(@opt_keys);
        
        # append default extruder
        push @opt_keys, 'extruder';
        $default_config->set('extruder', 0);
        $config->set_ifndef('extruder', 0);
    }
    
    $self->{canvas}->Render if $self->{canvas};
}


# Load button event
sub LoadButtenPressed {
    my $self = shift;
    my ($file) = @_;
    
    if (!$file) {
        #my $dir = $last_config ? dirname($last_config) : $Slic3r::GUI::Settings->{recent}{config_directory} || $Slic3r::GUI::Settings->{recent}{skein_directory} || '';
        my $dlg = Wx::FileDialog->new(
            $self, 
            'Select schematic to load:',
            '',
            '',
            &Slic3r::GUI::FILE_WILDCARDS->{sch}, 
            wxFD_OPEN | wxFD_FILE_MUST_EXIST);
        return unless $dlg->ShowModal == wxID_OK;
        $file = Slic3r::decode_path($dlg->GetPaths);
        $dlg->Destroy;
    }
    @{$self->{schematic}} = Slic3r::Electronics::Electronics->readFile($file);
    $self->reload_tree;
}

# Save button event
sub SaveButtenPressed {
    print "Save pressed\n"
}

# Export button event
sub ExportButtenPressed {
    print "Export pressed\n"
}

1;

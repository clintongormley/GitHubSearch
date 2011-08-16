package GitHub::Label;

use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';

use base 'GitHub::Base';
use GitHub::Iterator();
use List::MoreUtils qw(none);

#===================================
sub type {'label'}
#===================================

#===================================
sub new {
#===================================
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my %params = @_;
    return $class->get( $params{id} );
}

#===================================
sub get_all_for_repo {
#===================================
    my $class  = shift;
    my %params = @_;
    my $repo   = $params{repo};

    my $search = $class->es->scrolled_search(
        type => 'label',
        size => 100,
        queryb => { -filter => { repo => $repo->id } },
        sort   => [         { 'id'    => 'asc' } ]
    );

    my @labels;
    while ( my $label = $search->next ) {
        $label = $label->{_source};
        bless $label, $class;
        push @labels, $label;
    }

    return \@labels;
}

#===================================
sub bulk_add {
#===================================
    my $class = shift;
    my @ids;
    for my $label (@_) {
        $label->{$_} || die "No $_ specified" for qw(repo name color url);
        my $id = $label->{repo} . '/' . $label->{name};
        $label->{id} = $id;
        $class->bulk_index( { type => 'label', id => $id, data => $label } );
        push @ids, $id;
    }
    return \@ids;
}

#===================================
sub id    { shift->{id} }
sub name  { shift->{name} }
sub color { shift->{color} }
sub url   { shift->{url} }
#===================================

#===================================
sub mapping {
#===================================
    return {
        properties => {
            id    => { type  => 'string', index => 'not_analyzed' },
            repo  => { type  => 'string', index => 'not_analyzed' },
            name  => { type  => 'string', index => 'not_analyzed' },
            color => { index => 'no',     type  => 'string' },
            url   => { index => 'no',     type  => 'string' },
        },
    };
}

1;

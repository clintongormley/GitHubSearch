package GitHub::Base;

use strict;
use warnings;
use GitHub::Index();

our $Flush_Size = 100;

#===================================
sub es {$GitHub::Index::ES}
#===================================

#===================================
sub get {
#===================================
    my $class = shift;
    my $type  = $class->type;
    my $id    = shift or die "No ID specified for $type";
    my $doc   = $class->es->get(
        type           => $type,
        id             => $id,
        ignore_missing => 1
    ) or die "No $type found with ID $id";
    return bless $doc->{_source}, $class;
}

#===================================
sub mget {
#===================================
    my $class = shift;
    my $ids   = shift;

    my $docs = $class->es->mget( type => $class->type, ids => $ids );
    return [ map { bless $_, $class } map { $_->{_source} } @$docs ];
}

our @buffer;
#===================================
sub bulk_index {
#===================================
    my $class = shift;
    push @buffer, shift;
    $class->flush_bulk() if @buffer == $Flush_Size;
}

#===================================
sub flush_bulk {
#===================================
    my $class    = shift;
    my $response = $class->es->bulk_index( \@buffer );
    @buffer = ();
    my $errors = $response->{errors}
        or return;

    die "Error flushing bulk index: \n"
        . $class->es->transport->JSON($errors);
}

1;

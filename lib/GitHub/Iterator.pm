package GitHub::Iterator;

use HTTP::Tiny;
use JSON();
use URI();

our $GitHub   = 'https://api.github.com/';
our $PageSize = 100;
our $JSON     = JSON->new->utf8;

#===================================
sub new {
#===================================
    my $class = shift;
    my $page  = shift;
    $page =~ s{^/}{};
    my %params = @_;
    my $url    = URI->new( $GitHub . $page );
    $url->query_form( per_page => $PageSize, %params );
    return bless {
        _buffer => [],
        _eof    => 0,
        _url    => $url->as_string,
    };
}

#===================================
sub all {
#===================================
    my $self = shift;
    my @docs;
    while ( my $next = $self->next ) {
        push @docs, $next;
    }
    return @docs;
}

#===================================
sub next {
#===================================
    my $self = shift;
    return undef if $self->eof;
    $self->_fetch_next_page()
        unless @{ $self->{_buffer} };
    return shift @{ $self->{_buffer} };
}

#===================================
sub _fetch_next_page {
#===================================
    my $self = shift;
    my $url  = $self->{_url}
        or return $self->{_eof} = 1;
    my $response = HTTP::Tiny->new->get($url);
    die "Failed to get $url: $response->{status} $response->{reason}"
        unless $response->{success};

    my $data = $JSON->decode( $response->{content} );
    $data = [$data] unless ref $data eq 'ARRAY';
    push @{ $self->{_buffer} }, @$data;

    my $link = $response->{headers}{link} || '';
    ( $self->{_url} ) = ( $link =~ /<([^>]+)>;\s+rel="next"/ );
}

#===================================
sub eof { shift->{_eof} }
#===================================

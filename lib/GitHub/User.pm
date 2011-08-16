package GitHub::User;

use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';

use base 'GitHub::Base';
use GitHub::Iterator();
use List::MoreUtils qw(none);

#===================================
sub type {'user'}
#===================================

#===================================
sub new {
#===================================
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my %params = @_;

    return $class->get( $params{id} )
        if $params{id};

    my $login = $params{login}
        or return undef;

    my $self = $class->get_by_login($login)
        || $class->remote( $params{login} );
    bless $self, $class;
}

#===================================
sub get_by_login {
#===================================
    my $class = shift;
    my $login = shift;
    my $doc   = $class->es->search(
        type => 'user',
        queryb => { -filter => { login => $login } }
        )->{hits}{hits}[0]
        or return;
    return $doc->{_source};
}

#===================================
sub search {
#===================================
    my $class    = shift;
    my %params   = @_;
    my $keywords = $params{keywords} or return [];
    my $repo     = $params{repo};

    my $results = $class->es->search(
        type   => 'user',
        queryb => {
            -filter => { repos => $repo->id },
            -or     => [
                'login.text' => { '=' => { query => $keywords, boost => 2 } },
                'login.ngrams' => $keywords,
                'email'        => $keywords,
                'name'         => $keywords,
                'name.ngrams'  => $keywords,
            ]
        }
    )->{hits}{hits};

    return [ map { bless $_, $class } map { $_->{_source} } @$results ];
}

#===================================
sub add_repo {
#===================================
    my $self = shift;
    my $repo = shift;

    my $repos = $self->{repos};
    if ( none { $_ eq $repo } @$repos ) {
        push @$repos, $repo;
        $self->es->index(
            type => 'user',
            id   => $self->id,
            data => {%$self},
        );
    }
    return $repo;
}

#===================================
sub remote {
#===================================
    my $class = shift;
    my $login = shift;
    my $data  = GitHub::Iterator->new( '/users/' . $login )->next()
        or die "No user found with login $login";

    my %doc = map { $_ => $data->{$_} }
        qw(id login name email avatar_url html_url blog);

    $doc{repos} = [];

    $class->es->index(
        type => 'user',
        id   => $doc{id},
        data => \%doc
    );
    return \%doc;
}

#===================================
sub id         { shift->{id} }
sub login      { shift->{login} }
sub name       { shift->{name} }
sub email      { shift->{email} }
sub avatar_url { shift->{avatar_url} }
sub html_url   { shift->{html_url} }
sub blog       { shift->{blog} }
#===================================

#===================================
sub mapping {
#===================================
    return {
        properties => {
            id         => { type => 'integer', index => 'no' },
            email      => { type => 'string' },
            avatar_url => { type => 'string',  index => 'no' },
            html_url   => { type => 'string',  index => 'no' },
            blog       => { type => 'string',  index => 'no' },
            repos      => { type => 'string',  index => 'not_analyzed' },
            login      => {
                type   => 'multi_field',
                fields => {
                    login => { type => 'string', index    => 'not_analyzed' },
                    text  => { type => 'string', analyzer => 'text' },
                    ngrams => {
                        type            => 'string',
                        index_analyzer  => 'ngram',
                        search_analyzer => 'text'
                    },
                }
            },
            name => {
                type   => 'multi_field',
                fields => {
                    name   => { type => 'string' },
                    ngrams => {
                        type            => 'string',
                        index_analyzer  => 'ngram',
                        search_analyzer => 'text'
                    }
                }
            },
        }
    };
}

1;

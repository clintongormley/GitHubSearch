package GitHub::Repo;

use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';

use v5.12;

use base 'GitHub::Base';
use GitHub::Iterator();
use GitHub::Issue();
use GitHub::User();
use GitHub::Label();

#===================================
sub type {'repo'}
#===================================

#===================================
sub new {
#===================================
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my %params = @_;
    my $user   = $params{user} or die "No user specified";
    my $name   = $params{name} or die "No repo name specified";

    my $id = lc "$user/$name";

    my $self
        = eval { $class->get($id) }
        || $class->remote( $user, $name )
        || die "Repo $id not found";
    bless $self, $class;
}

#===================================
sub get_all {
#===================================
    my $class = shift;
    my @repos;
    my $search = $class->es->scrolled_search(
        type => 'repo',
        sort   => { id => 'asc' },
        scroll => '10s'
    );
    while ( my $repo = $search->next ) {
        $repo = $repo->{_source};
        push @repos, bless $repo, $class;
    }
    return \@repos;
}

#===================================
sub remote {
#===================================
    my $class = shift;
    my $user  = shift;
    my $name  = shift;
    my $id    = shift;

    my $data = GitHub::Iterator->new("/repos/$user/$name")->next()
        or return;

    my $login = $data->{owner}{login};
    $id = lc( $login . '/' . $data->{name} );
    my $owner = GitHub::User->new( login => $login );
    $owner->add_repo($id);

    my %doc = (
        id       => $id,
        user     => $login,
        name     => $data->{name},
        html_url => $data->{html_url},
        owner_id => $owner->id,
    );

    $class->es->index( type => 'repo', id => $id, data => \%doc );
    return \%doc;
}

#===================================
sub update_issues {
#===================================
    my $self         = shift;
    my $repo_id      = $self->id;
    my $last_updated = $self->last_updated;

    say "Updating issues since $last_updated";

    for my $state (qw(open closed)) {
        my $issues_it = GitHub::Iterator->new(
            "repos/$repo_id/issues",
            state     => $state,
            since     => $last_updated,
            sort      => 'updated',
            direction => 'asc'
        );
        while ( my $issue = $issues_it->next ) {
            $issue->{repo} = $self->id;
            GitHub::Issue->bulk_add($issue);
        }
    }

    $self->flush_bulk();

}

#===================================
sub last_updated {
#===================================
    my $self         = shift;
    my $last_updated = $self->es->search(
        type        => 'issue',
        search_type => 'count',
        queryb => { -filter => { repo => $self->id } },
        facets => {
            issue => {
                terms_stats =>
                    { key_field => 'repo', value_field => 'updated_at' }
            }
        }
        )->{facets}{issue}{terms}[0]{max}
        or return '1970-01-01T00:00:00Z';

    my ( $s, $m, $h, $d, $M, $y ) = gmtime( int( $last_updated / 1000 ) );

    return sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ",
        $y + 1900, $M + 1, $d, $h, $m, $s;

}

#===================================
sub id       { shift->{id} }
sub user     { shift->{user} }
sub name     { shift->{name} }
sub html_url { shift->{html_url} }
sub owner_id { shift->{owner_id} }
#===================================

#===================================
sub owner {
#===================================
    my $self = shift;
    $self->{owner} ||= GitHub::User->new( id => $self->owner_id );
}

#===================================
sub mapping {
#===================================
    return {
        properties => {
            id       => { type => 'string', index => 'no' },
            user     => { type => 'string', index => 'not_analyzed' },
            name     => { type => 'string', index => 'not_analyzed' },
            owner_id => { type => 'integer' },
            html_url => { type => 'string', index => 'no' },
        }
    };
}

1;

=head1 AUTHOR

Clinton Gormley, E<lt>clinton@traveljury.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Clinton Gormley

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut

1

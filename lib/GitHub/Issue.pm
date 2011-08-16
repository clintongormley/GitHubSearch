package GitHub::Issue;

use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';

use v5.10;

use GitHub::Iterator();
use base 'GitHub::Base';
use Text::Markdown::GitHub qw(markdown);

#===================================
sub type {'issue'}
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
sub label_counts {
#===================================
    my $class  = shift;
    my %params = @_;
    my $repo   = $params{repo};
    my $max    = $params{max} || 1000;

    my $counts = $class->es->search(
        type        => 'issue',
        search_type => 'count',
        queryb => { -filter => { repo => $repo->id } },
        facets => {
            labels => {
                terms => {
                    field => 'label_ids',
                    size  => $max,
                }
            }
        }
    )->{facets}{labels}{terms};

    my %labels = map { $_->{term} => $_->{count} } @$counts;

    return \%labels;
}

my %User_Roles = (
    creator  => 'user_id',
    assignee => 'assignee_id',
    comment  => 'comments.user_id',
);

#===================================
sub search {
#===================================
    my $class  = shift;
    my %params = @_;

    my $filters = $class->_query_filters( \%params );
    my $keywords = $params{keywords} // '';
    $keywords =~ s/^\s+//;
    $keywords =~ s/\s+$//;

    my $search
        = length($keywords)
        ? $class->_keyword_search( $keywords, $filters )
        : {
        queryb => { -filter    => $filters },
        sort   => { updated_at => 'desc' },
        };

    my $state = $params{state};

    if ( my $min_date = $params{min_date} ) {
        $search->{filterb}{created_at}{'>='} = $min_date;
    }
    if ( my $max_date = $params{max_date} ) {
        $search->{filterb}{created_at}{'<='} = $max_date;
    }

    my $timeline_facet;
    if ($state) {
        $search->{filterb}{state} = $state;
        $timeline_facet = {
            key_field    => 'created_at',
            interval     => 'week',
            value_script => "doc['state'].value == '$state' ? 1 : 0"
        };
    }
    else {
        $timeline_facet = { field => 'created_at', interval => 'week' };
    }

    my $results = $class->es->search(
        %$search,
        type   => 'issue',
        facets => {
            state    => { terms          => { field => 'state' } },
            timeline => { date_histogram => $timeline_facet }
        },
    );


    return {
        total        => $results->{hits}{total},
        issues       => $class->_inflate_issues($results),
        highlights   => $class->_highlights($results),
        state_counts => $class->_state_counts( $state, $results ),
        timeline     => $class->_timeline( $state, $results ),
    };
}

#===================================
sub _query_filters {
#===================================
    my $class   = shift;
    my $params  = shift;
    my $repo_id = $params->{repo}->id;
    my %filters = ( repo => $repo_id );

    my @labels = map {"$repo_id/$_"} @{ $params->{labels} || [] };
    $filters{label_ids} = \@labels if @labels;

    if ( my $user_id = $params->{user_id} ) {
        my $role = $params->{user_type} || '';
        $filters{-or} = [ map { $_ => $user_id } $User_Roles{$role}
                || values %User_Roles ];
    }
    return \%filters;
}

#===================================
sub _keyword_search {
#===================================
    my $class    = shift;
    my $keywords = shift;
    my $filters  = shift;

    return {
        queryb => {
            -filter => $filters,
            -or     => {
                'number' => { '=' => { query => $keywords, boost => 100 } },
                'title'  => { '=' => { query => $keywords, boost => 5 } },
                'title.ngrams' => $keywords,
                'body'         => $keywords,
                'comment.body' => $keywords,
            },
        },
        highlight => {
            fields => {
                'title'        => { number_of_fragments => 0 },
                'title.ngrams' => { number_of_fragments => 0 },
                'body'         => {
                    fragment_size       => 200,
                    number_of_fragments => 3,
                    fragment_offset     => 20,
                    pre_tags            => ['[TAG_BEGIN]'],
                    post_tags           => ['[TAG_END]'],
                },
            }
        },
    };
}

#===================================
sub _inflate_issues {
#===================================
    my $class   = shift;
    my $results = shift;
    my $hits    = $results->{hits}{hits};

    my ( @issues, %user_ids, %label_ids );

    for (@$hits) {
        my $issue = $_->{_source};
        bless $issue, $class;

        for (qw(assignee_id user_id)) {
            $user_ids{ $issue->$_ || 0 }++;
        }

        for ( @{ $issue->comments } ) {
            $user_ids{ $_->{user_id} }++;
        }

        $label_ids{$_}++ for @{ $issue->label_ids };

        push @issues, $issue;
    }

    delete $user_ids{0};

    my $users = GitHub::User->mget( [ keys %user_ids ] );
    $user_ids{ $_->id } = $_ for @$users;

    my $labels = GitHub::Label->mget( [ keys %label_ids ] );
    $label_ids{ $_->id } = $_ for @$labels;

    for my $issue (@issues) {
        $issue->{user} = $user_ids{ $issue->user_id };
        $issue->{assignee} = $user_ids{ $issue->assignee_id || 0 };

        for my $comment ( @{ $issue->comments } ) {
            $comment->{user} = $user_ids{ $comment->{user_id} };
        }

        $issue->{labels} = [ map { $label_ids{$_} } @{ $issue->label_ids } ];
    }

    return \@issues;
}

#===================================
sub _state_counts {
#===================================
    my $class  = shift;
    my $state  = shift;
    my $counts = shift->{facets}{state}{terms};

    my %states = ( selected => $state || 'all', all => 0 );
    for (@$counts) {
        $states{all} += $_->{count};
        $states{ $_->{term} } = $_->{count};
    }
    return \%states;
}

#===================================
sub _timeline {
#===================================
    my $class  = shift;
    my $state  = shift;
    my $counts = shift->{facets}{timeline}{entries};

    my $facet_key = $state ? 'total' : 'count';
    my @timeline = map { [ $_->{time}, $_->{$facet_key} ] } @$counts;
    return \@timeline;
}

#===================================
sub _highlights {
#===================================
    my $class = shift;

    my $hits = shift->{hits}{hits}
        or return {};

    my %highlights;

    for (@$hits) {

        my $phrases = $highlights{ $_->{_id} } = $_->{highlight}
            || next;

        $phrases->{'title_ngrams'} = delete $phrases->{'title.ngrams'};

        for ( @{ $phrases->{body} || [] } ) {
            $_ = GitHub::Web::_trim_html($_);
            s{ \[TAG_BEGIN\] (.*?) \[TAG_END\] }{<em>$1</em>}sgx;
        }

        for ( keys %$phrases ) {
            my $val = $phrases->{$_} or next;
            $phrases->{$_} = join ' ... ', @$val;
            $phrases->{$_} =~ s{</em>(\s*)\s*<em>}{$1}g;
        }

    }
    return \%highlights;

}

#===================================
sub bulk_add {
#===================================
    my $class = shift;
    my $data  = shift;

    my $repo = $data->{repo};
    my $num  = $data->{number};
    my $id   = $repo . '/' . $num;

    my %doc = map { $_ => $data->{$_} } qw(
        id number state title html_url
        created_at closed_at updated_at
    );

    say "Adding issue $num";

    $doc{id}               = $id;
    $doc{repo}             = $repo;
    $doc{body}             = markdown( $data->{body} );
    $doc{user_id}          = _get_user_id( $repo, $data->{user} );
    $doc{assignee_id}      = _get_user_id( $repo, $data->{assignee} );
    $doc{pull_request_url} = $data->{pull_request}{html_url}
        if $data->{pull_request};

    my @labels = map { $_->{repo} = $repo; $_ } @{ $data->{labels} };
    $doc{label_ids} = GitHub::Label->bulk_add(@labels);

    if ( $data->{comments} ) {
        my $it = GitHub::Iterator->new("repos/$repo/issues/$num/comments");
        while ( my $comment = $it->next ) {
            push @{ $doc{comments} },
                {
                id         => $comment->{id},
                body       => markdown( $comment->{body} ),
                created_at => $comment->{created_at},
                updated_at => $comment->{updated_at},
                user_id    => _get_user_id( $repo, $comment->{user} )
                };
        }
    }
    $class->bulk_index( { type => 'issue', id => $id, data => \%doc } );

}

#===================================
sub _get_user_id {
#===================================
    my $repo = shift;
    my $data = shift or return;
    my $user = GitHub::User->new( login => $data->{login} );
    $user->add_repo($repo);
    return $user->id;
}

#===================================
sub id               { shift->{id} }
sub number           { shift->{number} }
sub state            { shift->{state} }
sub title            { shift->{title} }
sub html_url         { shift->{html_url} }
sub created_at       { shift->{created_at} }
sub closed_at        { shift->{closed_at} }
sub updated_at       { shift->{updated_at} }
sub user_id          { shift->{user_id} }
sub assignee_id      { shift->{assignee_id} }
sub pull_request_url { shift->{pull_request_url} }
sub label_ids        { shift->{label_ids} || [] }
sub comments         { shift->{comments} || [] }
#===================================

#===================================
sub user {
#===================================
    my $self = shift;
    $self->{user} ||= GitHub::User->new( id => $self->user_id );
}

#===================================
sub assignee {
#===================================
    my $self = shift;
    $self->{assignee} ||= GitHub::User->new( id => $self->assignee_id );
}

#===================================
sub mapping {
#===================================
    return {
        properties => {
            id          => { type => 'string', index => 'no' },
            repo        => { type => 'string', index => 'not_analyzed' },
            number      => { type => 'string', index => 'not_analyzed' },
            state       => { type => 'string', index => 'not_analyzed' },
            assignee_id => { type => 'integer' },
            user_id     => { type => 'integer' },
            created_at  => { type => 'date' },
            closed_at   => { type => 'date' },
            updated_at  => { type => 'date' },
            html_url    => { type => 'string', index => 'no' },
            label_ids   => { type => 'string', index => 'not_analyzed' },
            title       => {
                type   => 'multi_field',
                fields => {
                    title => {
                        boost       => 2,
                        type        => 'string',
                        analyzer    => 'text',
                        store       => 'yes',
                        term_vector => 'with_positions_offsets'
                    },
                    ngrams => {
                        type            => 'string',
                        index_analyzer  => 'ngram',
                        search_analyzer => 'text',
                        store           => 'yes',
                        term_vector     => 'with_positions_offsets'
                    },
                }
            },
            body => {
                type        => 'string',
                store       => 'yes',
                term_vector => 'with_positions_offsets',
                analyzer    => 'html',
            },
            comments => {
                type            => 'nested',
                include_in_root => 1,
                properties      => {
                    body => {
                        type        => 'string',
                        store       => 'yes',
                        term_vector => 'with_positions_offsets',
                        analyzer    => 'html',
                    },
                    created_at => { type => 'date' },
                    updated_at => { type => 'date' },
                    url     => { type => 'string', index => 'no', },
                    user_id => { type => 'integer' },
                    id      => { type => 'integer' },
                },
            },
            pull_request_url => { type => 'string', index => 'no' },
        }
    };
}
1;

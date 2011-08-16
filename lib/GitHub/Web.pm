package GitHub::Web;

use strict;
use warnings;

use Plack::Request();
use Template();
use FindBin;
use Time::Local;
use HTML::Entities qw(decode_entities encode_entities);
use Encode qw(encode_utf8 decode_utf8);
use List::Util qw(min max);
use JSON();
use GitHub::Repo();

our $JSON     = JSON->new->utf8;
our %Handlers = (
    '/'       => \&home,
    '/issues' => \&issues,
    '/users'  => \&users,
);

our $TT = Template->new( {
        INCLUDE_PATH => $FindBin::Bin . '/../templates',
        ENCODING     => 'utf8',
    }
) or die "$Template::ERROR\n";

#===================================
sub request {
#===================================
    my $req        = Plack::Request->new(shift);
    my $req_params = $req->parameters;
    my $path_info  = $req->path_info || '/';

    my $repo;
    if ( $path_info =~ s{^/([-a-z_.0-9]+)/([-a-z_.0-9]+)}{}i ) {
        $repo = GitHub::Repo->new( user => $1, name => $2 );
    }
    $path_info = '/' unless $repo;

    my $handler = $Handlers{$path_info}
        || die "No handler for $path_info";

    my $resp_params = $handler->( $repo, $req_params );

    my $resp     = $req->new_response(200);
    my $template = delete $resp_params->{template};

    if ( $template eq 'json' ) {
        $resp->body( _to_json( $resp_params->{data} ) );
        $resp->content_type('text/json; charset=utf-8');
    }
    else {
        $resp_params->{repo} = $repo;
        my $body = _render( $template, $resp_params );

        $resp->content_type('text/html; charset=utf-8');
        $resp->body( encode_utf8($body) );

    }

    $resp->finalize;
}

#===================================
sub home {
#===================================
    my $repo   = shift;
    my $params = shift;

    my $response;
    if ($repo) {
        my $labels = GitHub::Label->get_all_for_repo( repo => $repo );
        my $label_counts = GitHub::Issue->label_counts(
            repo => $repo,
            max  => scalar @$labels
        );
        $response = GitHub::Issue->search( %$params, repo => $repo );
        $response->{labels}       = $labels;
        $response->{label_counts} = $label_counts;
    }
    else {
        $response = { repos => GitHub::Repo->get_all };
    }

    $response->{template} = 'home';
    return $response;

}

#===================================
sub issues {
#===================================
    my $repo    = shift;
    my $params  = shift;
    my $results = GitHub::Issue->search(
        repo   => $repo,
        labels => [ $params->get_all('label') ],
        map { $_ => $params->{$_} }
            qw(keywords user_id user_type min_date max_date state)
    );

    return {
        template => 'issues_list',
        %$results,
    };
}

#===================================
sub users {
#===================================
    my $repo   = shift;
    my $params = shift;
    my $users
        = GitHub::User->search( keywords => $params->{term}, repo => $repo );
    my @results;
    for my $user (@$users) {
        my $name = $user->name || '';
        $name = " ($name)" if $name;
        push @results, { id => $user->id, label => $user->login . $name }

    }
    return {
        template => 'json',
        data     => \@results,
    };
}

#===================================
sub _render {
#===================================
    my $template    = shift() . '.tt';
    my $resp_params = shift;

    my $body = '';
    $resp_params->{fuzzy}         = \&_fuzzy_time;
    $resp_params->{trim_html}     = \&_trim_html;
    $resp_params->{gradient}      = \&_to_gradient;
    $resp_params->{contrast_text} = \&_contrast_text;
    $resp_params->{json}          = \&_to_json;
    $TT->process( $template, $resp_params, \$body )
        || die "Error processing template $template: " . $TT->error() . "\n";

    return $body;
}

my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
#===================================
sub _fuzzy_time {
#===================================
    my $date = shift or return '';
    my ( $y, $M, $d, $h, $m, $s ) = split /[-:TZ]/, $date;
    my $epoch_date = Time::Local::timegm( $s, $m, $h, $d, $M - 1, $y );
    my $diff = time() - $epoch_date;

    if ( $diff > 3600 * 24 * 7 ) {
        my ( $d, $m, $y ) = ( gmtime($epoch_date) )[ 3, 4, 5 ];
        return join( ' ', $d, $months[$m], $y + 1900 );
    }

    return sprintf "%.0f days ago", $diff / ( 24 * 3600 )
        if $diff > 3600 * 24 * 2;

    return "yesterday"
        if $diff > 3600 * 24;

    return sprintf "%.0f hours ago", $diff / 3600
        if $diff > 5400;

    return sprintf "one hour ago", $diff / 3600
        if $diff >= 3600;

    return sprintf "%.0f minutes ago", $diff / 60
        if $diff > 90;

    return "one minute ago"
        if $diff >= 60;

    return sprintf "%d seconds ago", $diff;
}

#===================================
sub _trim_html {
#===================================
    my $text   = shift;
    my $max    = shift || 0;
    my $suffix = '...';

    $text =~ s/<[^>]*>/ /g;
    $text =~ s/[<> ]+/ /g;
    $text =~ s/\s+/ /g;
    $text =~ s{ $}{};
    $text =~ s/^ //;

    $text = decode_entities($text);

    if ( $max && length $text > $max ) {
        $max -= length($suffix);
        $max = 0 if $max < 0;

        my $min = $max - 20;
        unless ( $min > 0 and $text =~ s/^(.{$min,$max})\s.*/$1/s ) {
            $text = substr( $text, 0, $max );
            $text =~ s/&[^;]*$//;
        }
        $text .= $suffix;
    }
    return encode_entities( $text, q(<>&") );
}

#===================================
sub _to_gradient {
#===================================
    my $hex = shift;
    my ( $start, $end ) = ('') x 2;
    while ( $hex =~ /(..)/g ) {
        my $val = hex $1;
        $start .= sprintf "%02x", $val * 0.80;
        $end .= sprintf "%02x", min( $val * 1.1, 245 );
    }
    return <<"STYLE";
    filter: progid:DXImageTransform.Microsoft.gradient(GradientType=0, startColorstr='#$start', endColorstr='#$end');
    background: -webkit-gradient(linear, left top, left bottom, from(#$start), to(#$end));
    background: -moz-linear-gradient(top, #$start, #$end);
STYLE
}

#===================================
sub _contrast_text {
#===================================
    my ( $bg, $dark, $light ) = @_;
    my ( $r1, $g1,   $b1 )    = map { hex $_ } ( $bg =~ /(..)/g );
    my ( $r2, $g2,   $b2 )    = map { hex $_ } ( $light =~ /(..)/g );

    return (
        abs(( $r1 - $r2 ) * 299 + ( $g1 - $g2 ) * 587 + ( $b1 - $b2 ) * 114
            ) / 1000 > 125
            and abs(
                  max( $r1, $r2 )
                - min( $r1, $r2 )
                + max( $g1, $g2 )
                - min( $g1, $g2 )
                + max( $b1, $b2 )
                - min( $b1, $b2 )
            ) > 400
    ) ? $light : $dark;
}

#===================================
sub _to_json { $JSON->encode( shift() ) }
#===================================
1;

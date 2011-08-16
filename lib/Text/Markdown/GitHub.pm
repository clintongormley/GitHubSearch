package Text::Markdown::GitHub;

use strict;
use warnings;

use Text::Markdown();
use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(markdown);

#===================================
sub markdown {
#===================================
    my $content = shift // '';
    $content = encode_entities( $content, '<>&' );
    $content =~ s{&lt;(/?pre)&gt;}{<$1>}g;
    my %extractions;

    # Extract pre blocks
    my $extract = sub {
        my $content = shift // '';
        my $md5 = md5_hex($content);
        $extractions{$md5} = $content;
        return "{gfm-extraction-$md5}";
    };

    $content =~ s{(<pre>.*?</pre>)}{$extract->($1)}ges;

    # prevent foo_bar_baz from ending up with an italic word in the middle
    my $underscores = sub {
        my $content = shift // '';
        $content =~ s/_/\\_/g
            if ( $content =~ tr/_// ) > 1;
        return $content;
    };

    $content =~ s/(^(?! {4}|\t)\w+_\w+_\w[\w_]*)/$underscores->($1)/gem;

    # in very clear cases, let newlines become <br /> tags
    my $brs = sub {
        my $content = shift // '';
        return $content if $content =~ /\n\n/;
        $content =~ s/^\s+//;
        $content =~ s/\s+$//;
        return "$content  \n";
    };

    $content =~ s/^([\w<][^\n]*\n+)/$brs->($1)/gexm;

    # Insert pre block extractions
    $content =~ s/\{gfm-extraction-([0-9a-f]{32})\}/$extractions{$1}/ge;

    return Text::Markdown::markdown($content);
}

1

package GitHub::Index;

use strict;
use warnings;
use v5.10;

use ElasticSearch();
our $ES = ElasticSearch->new(
    servers   => '127.0.0.1:9200',
    use_index => 'github'
);

#$ES->trace_calls(1);

#===================================
sub create_index {
#===================================
    my $class = shift;

    say "Checking index";
    return if eval { $ES->index_exists };

    say "Index doesn't exist. Creating";
    my $settings = $class->index_settings;
    my %mappings = map { $_->type => $_->mapping }
        qw(GitHub::Repo GitHub::User GitHub::Label GitHub::Issue);

    $ES->create_index(
        settings => $settings,
        mappings => \%mappings
    );
    $ES->cluster_health( wait_for_status => 'yellow' );
}

#===================================
sub delete_index {
#===================================
    my $class = shift;
    say "Deleting index";
    $ES->delete_index( ignore_missing => 1 );
}

#===================================
sub index_settings {
#===================================
    return {
        analysis => {
            filter => {
                en => {
                  type=>'stemmer',
                  name => 'english',
                },
                edge_ngram => {
                    type     => 'edgeNGram',
                    min_gram => 1,
                    max_gram => 40
                },
                camelcase => {
                    type              => 'word_delimiter',
                    preserve_original => 1,
                },
            },
            analyzer => {
                text => {
                    type      => 'custom',
                    tokenizer => 'standard',
                    filter => [qw(standard camelcase lowercase asciifolding)],
                },
                html => {
                    type      => 'custom',
                    tokenizer => 'standard',
                    filter => [qw(standard camelcase en lowercase asciifolding)],
                    char_filter => ['html_strip'],
                },
                ngram => {
                    type      => 'custom',
                    tokenizer => 'standard',
                    filter =>
                        [qw(standard camelcase lowercase asciifolding edge_ngram)],
                },
            }
        }
    };
}

1

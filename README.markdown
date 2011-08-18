GitHub::Search is a demonstration of ElasticSearch and ElasticSearch.pm,
the Perl API.

To run this demo locally, you need to:

1) Install ElasticSearch:

    wget https://github.com/downloads/elasticsearch/elasticsearch/elasticsearch-0.17.6.tar.gz
    tar -xzf elasticsearch-0.17.6.tar.gz
    cd elasticsearch-0.17.6
    ./bin/elasticsearch -f

2) Install these Perl modules:

    sudo cpanm Digest::MD5
    sudo cpanm ElasticSearch
    sudo cpanm Encode
    sudo cpanm FindBin
    sudo cpanm HTML::Entities
    sudo cpanm HTTP::Tiny
    sudo cpanm IO::Socket::SSL
    sudo cpanm JSON
    sudo cpanm List::MoreUtils
    sudo cpanm List::Util
    sudo cpanm Net::SSLeay
    sudo cpanm Plack
    sudo cpanm Plack::Middleware::Deflater
    sudo cpanm Template
    sudo cpanm Text::Markdown
    sudo cpanm Time::Local
    sudo cpanm URI

3) Clone this repository:

    git clone git://github.com/clintongormley/GitHubSearch.git
    cd GitHubSearch

4) Add a repository:

    ./bin/issues.pl add elasticsearch/elasticsearch 

5) Run the webserver

    plack bin/app.psgi

Go to http://localhost:5000





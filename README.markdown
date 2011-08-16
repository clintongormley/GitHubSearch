GitHub::Search is a demonstration of ElasticSearch and ElasticSearch.pm,
the Perl API.

To run this demo locally, you need to:

1) Install ElasticSearch:

    wget https://github.com/downloads/elasticsearch/elasticsearch/elasticsearch-0.17.6.tar.gz
    tar -xzf elasticsearch-0.17.6.tar.gz
    cd elasticsearch-0.17.6
    ./bin/elasticsearch -f

2) Install these Perl modules:

    Digest::MD5
    ElasticSearch
    Encode
    FindBin
    HTML::Entities
    HTTP::Tiny
    IO::Socket::SSL
    JSON
    List::MoreUtils
    List::Util
    Net::SSLeay
    Plack
    Plack::Middleware::Deflater
    Template
    Text::Markdown
    Time::Local
    URI

3) Clone this repository:

    git clone git://github.com/clintongormley/GitHubSearch.git
    cd GitHubSearch

4) Add a repository:

    ./bin/issues.pl add elasticsearch/elasticsearch 

5) Run the webserver

    plack bin/app.psgi

Go to http://localhost:5000





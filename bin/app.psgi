use strict;
use warnings;
use Plack::Builder;

use FindBin;
use lib $FindBin::Bin.'/../lib' ;

use GitHub::Web;

builder {
  enable sub {
      my $app = shift;
      sub {
          my $env = shift;
          my $ua = $env->{HTTP_USER_AGENT} || '';
          # Netscape has some problem
          $env->{"psgix.compress-only-text/html"} = 1 if $ua =~ m!^Mozilla/4!;
          # Netscape 4.06-4.08 have some more problems
           $env->{"psgix.no-compress"} = 1 if $ua =~ m!^Mozilla/4\.0[678]!;
          # MSIE (7|8) masquerades as Netscape, but it is fine
          if ( $ua =~ m!\bMSIE (?:7|8)! ) {
              $env->{"psgix.no-compress"} = 0;
              $env->{"psgix.compress-only-text/html"} = 0;
          }
          $app->($env);
      }
  };
  enable "Deflater",
      content_type => ['text/css','text/html','text/javascript','application/javascript'],
      vary_user_agent => 1;
  enable 'Static',
        path => qr{\.(gif|png|jpg|ico|js|css)$},
        root => $FindBin::Bin.'/../static' ;

    \&GitHub::Web::request;
}

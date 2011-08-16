#!/usr/local/bin/perl

use strict;
use warnings;
use v5.12;
use FindBin;
use lib $FindBin::Bin. '/../lib';

use GitHub::Repo();

my %Actions = (
    add          => \&add_repo,
    delete       => \&delete_repo,
    update       => \&update_repo,
    delete_index => \&delete_index,
    help         => \&usage,
);

my $action = shift @ARGV or die usage();
my $handler = $Actions{$action}
    or die usage("Unknown action $action");

my $params = shift @ARGV;
if ($params) {
    $params =~ m{^([-a-z0-9_.]+)/([-a-z0-9_.]+)$}i
        or die usage("Couldn't understand repo $params");
    $params = { user => $1, name => $2 };
}

$handler->($params);

#===================================
sub add_repo {
#===================================
    my $params = shift or die usage("No repository specified");

    GitHub::Index->create_index();

    my $repo = GitHub::Repo->new(%$params);
    say "Added repo: " . $repo->id;

    $repo->update_issues;
}

#===================================
sub update_repo {
#===================================
    my $params = shift;
    my @repos
        = $params
        ? GitHub::Repo->new(%$params)
        : @{GitHub::Repo->get_all};

    for my $repo (@repos) {
        say "Updating repo " . $repo->id;
        $repo->update_issues;
    }
}

#===================================
sub delete_index {
#===================================
    GitHub::Index->delete_index();
}

#===================================
sub usage {
#===================================
    my $error = shift || '';
    $error = "ERROR: $error\n" if $error;
    return <<USAGE;
    $error
    USAGE:
            $0 add    user/repo
            $0 delete user/repo
            $0 update
            $0 update [user/repo]
            $0 delete_index

USAGE

}

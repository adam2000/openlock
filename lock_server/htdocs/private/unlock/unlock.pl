#!/usr/bin/perl -w

use strict;
use Apache2::RequestUtil;
use Apache2::Const;
use AnyEvent::JSONRPC::TCP::Client;
use Data::Dumper;

my $r = Apache2::RequestUtil->request;
#require Apache2::Access;

my $user = $r->user;

#my $client = RPC::XML::Client->new('http://localhost:1234/') or die "Could not start client: $@\n";
my $client = AnyEvent::JSONRPC::TCP::Client->new(
	host => '127.0.0.1',
	port => 1234,
);
#$r->log_error($r->connection->user());
#my $var = RPC::XML::string->new("$user");
#my $resp = $client->send_request('lockserver.validate', $var);
my $res = $client->call( validate => $user )->recv;

if ($res) {
	$client->call( unlock => $user )->recv;
	$r->headers_out->set(Location => '/private/unlock/door_open.pl');
}
else {
	$r->headers_out->set(Location => '/no_access.html');	
}
$r->status(Apache2::Const::REDIRECT);

return Apache2::Const::REDIRECT;

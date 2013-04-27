#!/usr/bin/perl -w

use strict;
use Apache2::RequestUtil;
use Apache2::Const;
use AnyEvent::JSONRPC::TCP::Client;
use Data::Dumper;

use lib qw( /etc/apache2/perl );
use LockServer::Db;

my $r = Apache2::RequestUtil->request;
#require Apache2::Access;

my $user = $r->user;
my $RPC_PORT = get_defaults('rpc_port') || 4004;

my $client = AnyEvent::JSONRPC::TCP::Client->new(
	host => '127.0.0.1',
	port => $RPC_PORT,
);

my $res = $client->call( validate_web => $user )->recv;

if ($res) {
	$client->call( unlock_web => $user )->recv;
	$r->headers_out->set(Location => '/private/unlock/door_open.pl');
}
else {
	$r->headers_out->set(Location => '/no_access.html');	
}
$r->status(Apache2::Const::REDIRECT);

return Apache2::Const::REDIRECT;

# end main

sub get_defaults {
	my $pref_name = shift;
	my $dbh_thr = LockServer::Db->my_connect or warn $!;
	my $sth_thr = $dbh_thr->prepare(qq[SELECT `value` FROM default_prefs WHERE `name` = ] . $dbh_thr->quote($pref_name));
	if ($sth_thr->execute) {
		my ($pref) = $sth_thr->fetchrow;
		$sth_thr->finish;
		$dbh_thr->disconnect;
		return $pref;
	}
	else {
		$sth_thr->finish;
		$dbh_thr->disconnect;
		syslog('info', "$!");
		return undef;
	}
}

sub get_user_defaults {
	my ($user, $pref_name) = @_;
	my $dbh_thr = LockServer::Db->my_connect or die $!;
	my $sth_thr = $dbh_thr->prepare(qq[SELECT `$pref_name` FROM users  WHERE username = ] . $dbh_thr->quote($user));
	if ($sth_thr->execute) {
		my ($pref) = $sth_thr->fetchrow;
		$sth_thr->finish;
		$dbh_thr->disconnect;
		if (defined($pref)) {
			return $pref;
		}
		else {
			$pref = get_defaults($pref_name);
			syslog('info', "no user pref $pref_name for $user, using default: $pref");
			return $pref;
		}
	}
	else {
		$sth_thr->finish;
		$dbh_thr->disconnect;
		syslog('info', "$!");
		return undef;
	}
}

#!/usr/bin/perl -w

use strict;
use Apache2::RequestUtil;
use DBI;
use Data::Dumper;
#use LockServer::Db;

use constant MY_DBI => 'DBI:mysql:database=lock_server;host=127.0.0.1;port=3306', 'lock_server', '';

my $r = Apache2::RequestUtil->request;

my $user = $r->user;
my $open_time = get_user_defaults($user, 'open_time');

$r->content_type("text/html");

my $html = <<HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<link href="/style_open.css" rel="stylesheet" type="text/css" />
	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
HTML
$html .= qq[	<META HTTP-EQUIV="REFRESH" content="$open_time; url=/">];
$html .= <<HTML;
	<title>Lock Server : Door is open</title>
</head>

<body>
<p>door is open</p>
<p><a href="/logout">logout</a></p>
</body>
</html>
HTML

$r->no_cache(1);
my $length = length($html);
$r->content_type("text/html");
$r->headers_out->set("Content-length","$length");
$r->headers_out->set("Pragma", "no-cache");

$r->print ($html);

# end main

sub get_defaults {
	my $pref_name = shift;
	my $dbh_thr = DBI->connect(MY_DBI) or warn $!;
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
	my $dbh_thr = DBI->connect(MY_DBI) or die $!;
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

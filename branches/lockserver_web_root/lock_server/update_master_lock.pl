#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Time::HiRes qw( usleep );
use DBI;
use Sys::Syslog;
use Digest::MD5 qw( md5_hex );

use lib qw( /etc/apache2/perl );
use LockServer::Db;

use constant GROUP => 'CA Ung';

openlog($0, "ndelay,pid", "local0");
syslog('info', "starting...");

$SIG{INT} = \&stop_lock_server;

syslog('info', "master lock updater started...");

update_poller();


sub update_poller {
	my $digest; # = '';
	my $remote;

	while (1) {
		my $md5 = Digest::MD5->new;
		
		my ($dbh, $dbh_remote, $sth, $sth_remote);
		if ($dbh = LockServer::Db->my_connect) {
			#$sth = $dbh->prepare(qq[SELECT `rfid` FROM `users` WHERE rfid is NOT NULL AND rfid != '' AND active = 1 AND (`active_from` is NULL OR (`active_from` < NOW())) AND (`expire_at` is NULL OR (NOW() < `expire_at`)) ORDER BY rfid LIMIT 100]);
			$sth = $dbh->prepare(qq[SELECT `username`, `active`, `name`, `rfid`, `mail`, `phone`, `group`, `open_time`, `sound_file`, `sound_repeat`, `sound_on_rfid_open`, `active_from`, `expire_at`, `comment` FROM `users` WHERE rfid is NOT NULL AND rfid != '' AND active = 1 AND (`active_from` is NULL OR (`active_from` < NOW())) AND (`expire_at` is NULL OR (NOW() < `expire_at`)) ORDER BY rfid LIMIT 100]);
			$sth->execute; # or die $!;
			#my $RFIDs = $sth->fetchall_arrayref;
			while ($_ = $sth->fetchrow_hashref) {
				$md5->add($$_{'username'});
				$md5->add($$_{'active'});
				$md5->add($$_{'name'});
				$md5->add($$_{'rfid'});
				$md5->add($$_{'mail'});
				$md5->add($$_{'phone'});
				$md5->add($$_{'open_time'});
				$md5->add($$_{'sound_file'});
				$md5->add($$_{'sound_repeat'});
				$md5->add($$_{'sound_on_rfid_open'});
				$md5->add($$_{'active_from'});
				$md5->add($$_{'expire_at'});
				$md5->add($$_{'comment'});
			}
			$sth->finish;

			$digest->{'current'} = $md5->hexdigest;

			if ($digest->{'current'} ne $digest->{'last'}) {
				# something changed...
				syslog('info', "updating users for main lock access");
				if ($dbh_remote = LockServer::Db->my_connect_remote) {
					# start transaction
					$dbh_remote->begin_work;
					$dbh_remote->do(qq[DELETE FROM `users` WHERE `group` = "] . GROUP . qq["]);
					$sth = $dbh->prepare(qq[SELECT `username`, `active`, `name`, `rfid`, `mail`, `phone`, `group`, `open_time`, `sound_file`, `sound_repeat`, `sound_on_rfid_open`, `active_from`, `expire_at`, `comment` FROM `users` WHERE rfid is NOT NULL AND rfid != '' AND active = 1 AND (`active_from` is NULL OR (`active_from` < NOW())) AND (`expire_at` is NULL OR (NOW() < `expire_at`)) ORDER BY rfid LIMIT 100]);
					$sth->execute; # or die $!;
					while ($_ = $sth->fetchrow_hashref) {
						syslog('info', "updating " . $$_{'name'} . " <" . $$_{'username'} . ">");
						$dbh_remote->do(qq[INSERT INTO `users` (`username`, `active`, `name`, `rfid`, `mail`, `phone`, `group`, `open_time`, `sound_file`, `sound_repeat`, `sound_on_rfid_open`, `active_from`, `expire_at`, `comment`) \
											VALUES ( \
											"$$_{'username'}", \
											1, \
											"$$_{'name'}", \
											"$$_{'rfid'}", \
											"$$_{'mail'}", \
											"$$_{'phone'}", \
											"] . GROUP . qq[", \
											"$$_{'open_time'}", \
											"$$_{'sound_file'}", \
											"$$_{'sound_repeat'}", \
											"$$_{'sound_on_rfid_open'}", \
											"$$_{'active_from'}", \
											"$$_{'expire_at'}", \
											"$$_{'comment'}")]);
					}
					$sth->finish;
					
					$dbh_remote->commit();
				}
				$dbh_remote->disconnect;

				$digest->{'last'} = $digest->{'current'};
			}
			$dbh->disconnect;
		}
		usleep(500_000);	# 0.5 sec
	}
}

sub stop_lock_server {
	syslog('info', "$0 stopped");
	exit;
}


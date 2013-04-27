#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Device::BCM2835;
use Device::SerialPort;
use Sys::Syslog;
use AnyEvent::JSONRPC::TCP::Server;
use DBI;
use Time::HiRes qw( usleep );
use threads;
use Thread::Suspend;
use Data::Dumper;

use lib qw( /etc/apache2/perl );
use LockServer::Db;

#use constant MY_SERVER_ROOT => '/var/www/lock_server';
my $MY_SERVER_ROOT = '/var/www/lock_server';

openlog($0, "ndelay,pid", "local0");
syslog('info', "starting...");

# connect to db
my $dbh;
if($dbh = LockServer::Db->my_connect) {
	$dbh->{'mysql_auto_reconnect'} = 1;
	syslog('info', "connected to db");
}
else {
	syslog('info', "cant't connect to db $!");
	die $!;
}

# get defaults from db
my $LOCK_PIN = get_defaults('lock_pin') || 0;
my $CONTACT_PIN = get_defaults('contact_pin') || 13;
my $RPC_PORT = get_defaults('rpc_port') || 4004;

$SIG{INT} = \&stop_lock_server;

# set up and clear lock interface
Device::BCM2835::init() || die "Could not init library";
Device::BCM2835::gpio_fsel(&Device::BCM2835::RPI_GPIO_P1_13, 
						   &Device::BCM2835::BCM2835_GPIO_FSEL_OUTP);
Device::BCM2835::gpio_fsel(&Device::BCM2835::RPI_GPIO_P1_26, 
						   &Device::BCM2835::BCM2835_GPIO_FSEL_OUTP);

ls_lock();
#syslog('info', "locked...");

# start servers...
my $port_name = '/dev/ttyAMA0';

my $thr_rfid_reader = threads->create('rfid_reader');
syslog('info', "rfid reader thread started...");

my $thr_button = threads->create('wait_for_button');
syslog('info', "button listener thread started...");

my $thr_rpc = threads->create('wait_for_rpc');
syslog('info', "RPC server thread started, listening on port $RPC_PORT");

syslog('info', "$0 started");

while (threads->list() > 0) {
	# do nothing
	usleep(1000_000);
}
syslog('info', "all threads stopped...");
syslog('info', "$0 stopped");
ls_lock();
#syslog('info', "locked...");
exit 1;

## END MAIN

sub rfid_reader {
	my ($port_obj, $count_in, $c);
	my $rfid = '';
	$port_obj = new Device::SerialPort($port_name) || die "Can't open $port_name: $!\n"; #, $quiet, $lockfile)
	$port_obj->baudrate(9600);
	$port_obj->databits(8);
	$port_obj->stopbits(1);
	$port_obj->parity("none");
	$port_obj->read_const_time(20);
	$port_obj->read_char_time(0);

	while (1) {
	
		($count_in, $c) = $port_obj->read(1);
		next unless ($count_in);
		
		unless (ord($c) == 13) {
			$rfid .= $c;
		}
		else {
			# we got a rfid tag...
			my $dbh_thr = LockServer::Db->my_connect or warn $!;
			if ($dbh_thr) {
				my $sth_thr = $dbh_thr->prepare(qq[SELECT `username`, `name`, `active`, `sound_on_rfid_open` FROM users WHERE rfid = ] . $dbh_thr->quote($rfid) . " AND (`active_from` is NULL OR (`active_from` < NOW())) AND (`expire_at` is NULL OR (NOW() < `expire_at`))");
				$sth_thr->execute || warn $!;
				my ($user, $name, $active, $sound_on_rfid_open) = $sth_thr->fetchrow;
				$sth_thr->finish;
				$dbh_thr->disconnect;

				if ($active) {
					unlock_rfid($user || $name, $rfid);
				}
				else {
					db_log(undef, $rfid, 'unauthorized', 'rfid');
					syslog('info', "rfid $rfid not authorized");

#	 				brute force resitance
#					usleep(1000_000);

				}

			}
			$rfid = '';
		}

	}
}

sub wait_for_button {
	# need to implement...
	while (1) {
		usleep(200_000);
	}
}

sub wait_for_rpc {
	my $server = AnyEvent::JSONRPC::TCP::Server->new(address => '127.0.0.1', port => $RPC_PORT );
	$server->reg_cb(
		unlock => \&rpc_handler_unlock,
		validate => \&rpc_handler_validate,
	);

	AnyEvent->condvar->recv;
}

sub rpc_handler_unlock {
	my $i;
	my ($res_cv, $user) = @_;

	my $dbh_thr = LockServer::Db->my_connect or warn $!;
	if ($dbh_thr) {
		my $sth_thr = $dbh_thr->prepare(qq[SELECT `username`, `active`, `sound_on_rfid_open` FROM users WHERE username = ] . $dbh_thr->quote($user) . " AND (`active_from` is NULL OR (`active_from` < NOW())) AND (`expire_at` is NULL OR (NOW() < `expire_at`))");
		$sth_thr->execute || warn $!;
		my ($user, $active, $sound_on_rfid_open) = $sth_thr->fetchrow;
		$sth_thr->finish;
		$dbh_thr->disconnect;

		if ($active) {
			$res_cv->result(1);
			unlock_web($user);
		}
		else {
			$res_cv->result(1);
			db_log($user, undef, 'unauthorized', 'web');
			syslog('info', "user $user not authorized");

#			brute force resitance
#			usleep(1000_000);
		}
	}
}

sub rpc_handler_validate {
	my $i;
	my ($res_cv, $user) = @_;

	my $dbh_thr = LockServer::Db->my_connect or warn $!;
	if ($dbh_thr) {
		my $sth_thr = $dbh_thr->prepare(qq[SELECT `username`, `active`, `sound_on_rfid_open` FROM users WHERE username = ] . $dbh_thr->quote($user) . " AND (`active_from` is NULL OR (`active_from` < NOW())) AND (`expire_at` is NULL OR (NOW() < `expire_at`))");
		$sth_thr->execute || warn $!;
		my ($user, $active, $sound_on_rfid_open) = $sth_thr->fetchrow;
		$sth_thr->finish;
		$dbh_thr->disconnect;

#		db_log($user, undef, 'validate', 'web');
#		syslog('info', "user $user validate");
		if ($active) {
			$res_cv->result(1);
		}
		else {
			$res_cv->result(undef);
		}
	}
}


sub stop_lock_server {
	my $thr;
	foreach (threads->list()) {
		syslog('info', "stopping thread" . $_->tid . "...");
		$_->detach;
		usleep(200_000);
	}
}

sub buzzer {
	my $user = shift;
	my $sound = get_user_defaults($user, 'sound_file');
	if (get_user_defaults($user, 'sound_repeat')) {
#		while (1) {
#			`/usr/bin/aplay $MY_SERVER_ROOT/sounds/$sound -q`;
#		}
	}
	else {
#			`/usr/bin/aplay $MY_SERVER_ROOT/sounds/$sound -q`;
	}
}

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
	my $dbh_thr = LockServer::Db->my_connect or warn $!;
	my $sth_thr = $dbh_thr->prepare(qq[SELECT `$pref_name` FROM users WHERE username = ] . $dbh_thr->quote($user));
	if ($sth_thr->execute) {
		my ($pref) = $sth_thr->fetchrow;
		$sth_thr->finish;
		$dbh_thr->disconnect;
		if (defined $pref) {
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

sub db_log {
	my ($user, $rfid, $message, $source) = @_;
	my $dbh_thr = LockServer::Db->my_connect or warn $!;
	my $sth_thr = $dbh_thr->prepare(qq[INSERT INTO `log` (`user`, 
																												`rfid`, 
																												`action`, 
																												`source`, 
																												`time_stamp`) 
																		 VALUES (] . $dbh_thr->quote($user) . ', ' . 
																		 						 $dbh_thr->quote($rfid) . ', ' . 
																		 						 $dbh_thr->quote($message) . ', ' .
																		 						 $dbh_thr->quote($source) . ', ' .
																		 						 'NOW())');
	$sth_thr->execute || syslog('info', "can't log to db");
	$sth_thr->finish;
	$dbh_thr->disconnect;
}

sub unlock_rfid {
	my ($user, $rfid) = @_;

	ls_unlock();
	my $thr_buzzer;
#	if ($sound_on_rfid_open) {
#		$thr_buzzer = threads->create('buzzer', $user);
#	}
	db_log($user, $rfid, 'unlock', 'rfid');
	syslog('info', "user $user unlocked with rfid: $rfid");
	usleep(get_user_defaults($user, 'open_time') * 1000_000);

	ls_lock();
#	if ($sound_on_rfid_open) {
#		$thr_buzzer->suspend;
#		$thr_buzzer->detach;
#	}
	db_log($user, $rfid, 'lock', 'rfid');
	syslog('info', "locked...");
}

sub unlock_web {
	my $user = shift;

	ls_unlock();
	my $thr_buzzer;
#	if ($sound_on_rfid_open) {
#		$thr_buzzer = threads->create('buzzer', $user);
#	}
	db_log($user, undef, 'unlock', 'web');
	syslog('info', "user $user unlocked");
	usleep(get_user_defaults($user, 'open_time') * 1000_000);

	ls_lock();
#	if ($sound_on_rfid_open) {
#		$thr_buzzer->suspend;
#		$thr_buzzer->detach;
#	}
	db_log($user, undef, 'lock', 'web');
	syslog('info', "locked...");
}

sub ls_unlock {
	Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_13, 1);
	Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_26, 1);
}

sub ls_lock {
	Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_13, 0);
	Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_26, 0);
}

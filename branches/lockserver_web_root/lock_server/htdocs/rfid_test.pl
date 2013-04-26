#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Device::SerialPort;
use DBI;
use threads;
use Data::Dumper;

use constant MY_DBI => 'DBI:mysql:database=lock_server;host=127.0.0.1;port=3306', 'lock_server', '';

# connect to db
my $dbh = DBI->connect(MY_DBI) || die $!;
my $port_name = '/dev/tty.usbserial-ftDWNUN6';
my $thr_rfid_reader = threads->create('rfid_reader');

while (threads->list() > 0) {
	# do nothing
}

exit 1;

## END MAIN

sub rfid_reader {
	my ($port_obj, $count_in, $string_in);
	$port_obj = new Device::SerialPort($port_name) || die "Can't open $port_name: $!\n"; #, $quiet, $lockfile)
	$port_obj->baudrate(9600);
	$port_obj->databits(8);
	$port_obj->stopbits(1);
	$port_obj->parity("none");

  while (($count_in, $string_in) = $port_obj->read(1)) {
#		warn "read unsuccessful\n" unless ($count_in == 1);
		if ($count_in) {
			print Dumper $string_in;
		}
	}
}


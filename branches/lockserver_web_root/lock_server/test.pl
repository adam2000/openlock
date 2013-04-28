#!/usr/bin/perl -w

use Device::BCM2835;
use Time::HiRes qw( usleep );
use strict;
use Data::Dumper;

#RPI_GPIO_P1_13 RELAY
#RPI_GPIO_P1_26 LED
# call set_debug(1) to do a non-destructive test on non-RPi hardware
#Device::BCM2835::set_debug(1);
Device::BCM2835::init() 
 || die "Could not init library";
 # outputs
Device::BCM2835::gpio_fsel(&Device::BCM2835::RPI_V2_GPIO_P1_13, 
						   &Device::BCM2835::BCM2835_GPIO_FSEL_OUTP);
Device::BCM2835::gpio_fsel(&Device::BCM2835::RPI_V2_GPIO_P1_26, 
                            &Device::BCM2835::BCM2835_GPIO_FSEL_OUTP);
# inputs
Device::BCM2835::gpio_fsel(&Device::BCM2835::RPI_V2_GPIO_P1_26, 
                            &Device::BCM2835::BCM2835_GPIO_FSEL_INPT );
Device::BCM2835::gpio_fsel(&Device::BCM2835::RPI_V2_GPIO_P1_26, 
                            &Device::BCM2835::BCM2835_GPIO_FSEL_INPT);

while (1)
{
    # Turn it on
#    Device::BCM2835::gpio_write(&Device::BCM2835::RPI_V2_GPIO_P1_26, 1);
	Device::BCM2835::gpio_write(&Device::BCM2835::RPI_V2_GPIO_P1_13, 1);
#    Device::BCM2835::delay(500); # Milliseconds
	usleep(200_000);
    # Turn it off
#    Device::BCM2835::gpio_write(&Device::BCM2835::RPI_V2_GPIO_P1_26, 0);
	Device::BCM2835::gpio_write(&Device::BCM2835::RPI_V2_GPIO_P1_13, 0);
#    Device::BCM2835::delay(500); # Milliseconds
	usleep(200_000);

	print Dumper(Device::BCM2835::gpio_lev(&Device::BCM2835::RPI_V2_GPIO_P1_07));
	print Dumper(Device::BCM2835::gpio_lev(&Device::BCM2835::RPI_V2_GPIO_P1_11));
}

__END__
Device::BCM2835::gpio_ren($pin);

my $value = Device::BCM2835::gpio_eds($pin);
if ($value) {
	# button pressed
	Device::BCM2835::gpio_set_eds($pin);
}


use Device::SerialPort;
use Data::Dumper;

my $port_name = '/dev/ttyAMA0';

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
			print Dumper($rfid);
			$rfid = '';
		}

	}
}

rfid_reader();



__END__

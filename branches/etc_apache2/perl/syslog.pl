#!/usr/bin/perl

use Sys::Syslog qw( :DEFAULT setlogsock );

setlogsock('unix');
openlog('apache2', 'cons', 'pid', 'local2');

while ($log = <STDIN>) {
  syslog('notice', $log);
}
closelog;

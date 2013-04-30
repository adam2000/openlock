#!/usr/bin/perl -w

use lib qw( /etc/apache2/perl );

#use Apache2::AuthTicket;
#use ModPerl::Registry;
use LockServer::Db;
use Embperl;
use AnyEvent::JSONRPC::TCP::Client;
use Data::Dumper;
use DBI;

1;

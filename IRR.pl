#!/usr/bin/perl
#
use lib '.';
use strict;
use warnings;
use Module::Configuration;
use Module::Process;
use Module::Timer;
use Module::Logger;
use Module::Bgpq3;

my $me = 'IRR';
open VERSION, '<', 'VERSION';
my $ver = readline(VERSION); chomp $ver;
close VERSION;
my $config = Module::Configuration->new('IRR.conf') or die "Couldn't create config from file IRR.conf";
my $logger = Module::Logger->new($config->logging());
$logger->level($logger->LOG_INFO);

if ($config->debug()) {
  $logger->options('perror');
  $logger->level($logger->LOG_DEBUG);
} else {
  die "this program should be run as root" unless $> == 0;
  my $pid = Module::Process::Daemonize(
    $config->general(),
    $config->directories('run')
  );
  $logger->notice("MAIN: forked successfully PID: $pid");
}

my $loop = 1;
my $frequency = 3600; # Hardcoded at 1 hour to prevent runtime config changes
my $timer = Module::Timer->new();
$logger->info("MAIN: started at " . $timer->startstr());
while ( $loop ) {
  $timer->update() and $logger->notice("MAIN: beginning query loop at " . $timer->laststr());
  my $now = $timer->laststr();
  my $worker = fork();
  unless ( $worker ) {
    # we are in the child process
    $logger->info("CHILD: trying to update configuration");
    # re-read config file and get required object names
    $config->update();
    my $routers = $config->routers();
    # re-hash data structure
    $logger->info("CHILD: building de-duplicated objects hash");
    my $objects = {};
    for my $router (keys %$routers) {
      for my $object (@{$routers->{$router}}) {
        $objects->{$object}->{'routers'} += 1;
      }
    }
    # initialize bgpq3
    my $bgpq3 = Module::Bgpq3->new($config->irr());
    my $afis = {
      ipv4 => {ver => 4, max_len => 24, name => 'ip'},
      ipv6 => {ver => 6, max_len => 48, name => 'ipv6'}
    };
    for my $object (keys %$objects) {
      my $strict = 1;
      if ($object =~ m/^AS37271:AS-PEERS:/i) {
        $strict = 0;
      }
      $logger->info("CHILD: building prefix-lists for $object");
      $objects->{$object}->{'prefix-list'} = "!\n";
      for my $af (keys %$afis) {
        $logger->info("CHILD: processing routes for address-family $af");
        my $entries = $bgpq3->prefixList($object, $afis->{$af}->{'ver'}, $afis->{$af}->{'max_len'}, $strict);
        my $count = scalar @$entries;
        $objects->{$object}->{'prefix-list'} .= "! $object - address family $af: $count entries\n";
        if ($count) {
          $objects->{$object}->{'prefix-list'} .= "no $afis->{$af}->{'name'} prefix-list $object\n";
          $objects->{$object}->{'prefix-list'} .= "$afis->{$af}->{'name'} prefix-list $object description Built by $me-$ver at $now\n";
          $logger->info("CHILD: have $count entries in address-family $af for object $object");
          for my $entry (@$entries) {
            $objects->{$object}->{'prefix-list'} .= "$entry\n";
          }
        } else {
          $logger->warning("CHILD: no entries found for $object in address-family $af");
        }
      }
    }
    $logger->info("CHILD: writing prefix-lists to file");
    for my $router (keys %$routers) {
      my $path = $config->directories('prefix-lists');
      $logger->info("CHILD: trying to open prefix-list file $path/$router");
      if (open(PL, ">$path/$router")) {
        for my $object (@{$routers->{$router}}) {
          print PL $objects->{$object}->{'prefix-list'};
        }
        print PL "!\n";
        print PL "end\n";
        close PL;
        $logger->info("CHILD: finished writing prefix-list file for $router");
      } else {
        $logger->err("CHILD: can't open $path/$router for read: $!");
      }
    }
    exit 0;
  }
  # we are back in the parent process
  $logger->notice("MAIN: waiting for worker process to complete");
  wait;
  $logger->notice("MAIN: worker process completed - going to sleep...");
  my $delay = $timer->delay($frequency);
  $logger->notice("MAIN: slept for $delay seconds");
}

$timer->update();
$logger->notice("MAIN: finished at " . $timer->laststr() . " after " . $timer->lifetime() . " seconds");
exit 0;

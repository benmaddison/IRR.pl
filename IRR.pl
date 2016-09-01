#!/usr/bin/perl
#
use strict;
use warnings;
use Module::Configuration;
use Module::Process;
use Module::Timer;
use Module::Logger;
use Module::RtConfig;

my $me = 'IRR';
open VERSION, '<', 'VERSION';
my $ver = readline(VERSION); chomp $ver;
close VERSION;
my $config = Module::Configuration->new('IRR.conf') or die "Couldn't create config from file IRR.conf";
my $logger = Module::Logger->new($config->logging());
$logger->level($logger->LOG_NOTICE);

if ($config->debug()) {
  use Data::Dumper;
  $logger->options('perror');
} else {
  my $pid = Module::Process::Daemonize($config->general());
  $logger->notice("MAIN: forked successfully PID: $pid");
}

my $loop = 1;
my $frequency = 28800; # Hardcoded at 8 hours to prevent runtime config changes
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
    # initialize RtConfig
    my $rtconfig = Module::RtConfig->new($config->irr());
    my $types = ['aut-num', 'as-set', 'route-set'];
    for my $object (keys %$objects) {
      my $defaults = {ip => '0.0.0.0/0 le 32', ipv6 => '::/0 le 128'};
      if ($object =~ m/^AS37271:AS-CUSTOMERS:/i) {
        $objects->{$object}->{'filters'} = {
          ip => "afi ipv4.unicast ($object AND {0.0.0.0/0^8-24})",
          ipv6 => "afi ipv6.unicast ($object AND {::/0^16-48})"
        };
      } elsif ($object =~ m/^AS37271:AS-PEERS:/i) {
        $objects->{$object}->{'filters'} = {
          ip => "afi ipv4.unicast ($object^+ AND {0.0.0.0/0^8-24})",
          ipv6 => "afi ipv6.unicast ($object^+ AND {::/0^16-48})"
        };
      } else {
        $objects->{$object}->{'filters'} = {
          ip => "afi ipv4.unicast $object",
          ipv6 => "afi ipv6.unicast $object"
        };
      }
      $logger->info("CHILD: building prefix-lists for $object");
      $objects->{$object}->{'prefix-list'} = "!\n";
      for my $af (keys %{$objects->{$object}->{'filters'}}) {
        $logger->info("CHILD: processing routes for address-family $af");
        my $prefixes = $rtconfig->prefixes($objects->{$object}->{'filters'}->{$af}, 1);
        my $count = scalar @$prefixes;
        $objects->{$object}->{'prefix-list'} .= "! address family $af: $count prefixes\n";
        if ($count) {
          $objects->{$object}->{'prefix-list'} .= "no $af prefix-list $object\n";
          $objects->{$object}->{'prefix-list'} .= "$af prefix-list $object description Built by $me-$ver at $now\n";
          $logger->info("CHILD: have $count routes in address-family $af for object $object");
          my $i = 0;
          for my $p (@$prefixes) {
            $i++;
            my $seq = $i * 10;
            if ($p->{'n'} eq $p->{'l'}) {
              if ($p->{'m'} eq $p->{'l'}) {
                $objects->{$object}->{'prefix-list'} .= "$af prefix-list $object seq $seq permit $p->{'p'}/$p->{'l'}\n";
              } else {
                $objects->{$object}->{'prefix-list'} .= "$af prefix-list $object seq $seq permit $p->{'p'}/$p->{'l'} le $p->{'m'}\n";
              }
            } else {
              $objects->{$object}->{'prefix-list'} .= "$af prefix-list $object seq $seq permit $p->{'p'}/$p->{'l'} ge $p->{'n'} le $p->{'m'}\n";
            }
          }
        } else {
          $logger->notice("CHILD: no prefixes found for $object in address-family $af");
#          $objects->{$object}->{'prefix-list'} .= "$af prefix-list $object seq 10 deny $defaults->{$af}\n";
        }
      }
    }
    $logger->info("CHILD: writing prefix-lists to file");
    for my $router (keys %$routers) {
      my $path = $config->directories('prefix-lists');
      $logger->info("CHILD: trying to open prefix-list file $path/$router");
      open PL, '>', "$path/$router";
      for my $object (@{$routers->{$router}}) {
        print PL $objects->{$object}->{'prefix-list'};
      }
      print PL "end\n";
      close PL;
      $logger->info("CHILD: finished writing prefix-list file for $router");
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

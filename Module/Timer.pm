#!/usr/bin/perl
#
package Module::Timer;
use Time::HiRes qw(time alarm sleep);

sub new {
  my $class = shift;
  my $now = time();
  my $data = {
    start => $now,
    last => $now,
    lifetime => 0,
    interval => 0,
    restarts => 0
  };
  my $self = bless $data, $class;
  return $self;
}

sub update {
  my $self = shift;
  my $now = time();
  $self->{'lifetime'} = $now - $self->{'start'};
  $self->{'interval'} = $now - $self->{'last'};
  $self->{'last'} = $now;
  return $self;
}

sub restart {
  my $self = shift;
  my $now = time();
  $self->{'start'} = $now;
  $self->{'last'} = $now;
  $self->{'lifetime'} = 0;
  $self->{'interval'} = 0;
  $self->{'restarts'}++;
  return $self;
}

sub start {
  my $self = shift;
  return $self->{'start'};
}

sub startstr {
  my $self = shift;
  return localtime($self->{'start'});
}

sub last {
  my $self = shift;
  return $self->{'last'};
}

sub laststr {
  my $self = shift;
  return localtime($self->{'last'});
}

sub lifetime {
  my $self = shift;
  return $self->{'lifetime'};
}

sub interval {
  my $self = shift;
  return $self->{'interval'};
}

sub delay {
  my $self = shift;
  my $delay = shift();
  my $interval = $self->update()->interval();
  my $sleep =  $delay - $interval ge 0 ? $delay - $interval : 0;
  my $slept = sleep($sleep);
  return $slept;
}

return 1;

#!/usr/bin/perl
#
package Module::Configuration;
use Data::Dumper;

sub new {
  my $class = shift;
  my $file = shift;
  my $config = do $file or return undef;
  my $data = { file => $file, config => $config };
  my $self = bless $data, $class;
  return $self;
}

sub update {
  my $self = shift;
  $self->{'config'} = do $self->{'file'} or return undef;
  return $self;
}

sub debug {
  my $self = shift;
  return $self->{'config'}->{'debug'};
}

sub general {
  my $self = shift;
  return $self->{'config'}->{'general'};
}

sub directories {
  my $self = shift;
  my $directory = shift;
  return $self->{'config'}->{'directories'}->{$directory};
}

sub irr {
  my $self = shift;
  return $self->{'config'}->{'irr'};
}

sub logging {
  my $self = shift;
  return $self->{'config'}->{'logging'};
}

sub routers {
  my $self = shift;
  return $self->{'config'}->{'routers'};
}

return 1;

#!/usr/bin/perl
#
package Module::Bgpq3;
use Data::Dumper;

sub new {
  my $class = shift;
  my $config = shift;
  $config->{'path'} = '/usr/bin/env bgpq3' unless $config->{'path'};
  $config->{'host'} = 'whois.radb.net' unless $config->{'host'};
  $config->{'port'} = 43 unless $config->{'port'};
  $config->{'protocol'} = 'irrd' unless $config->{'protocol'};
  $config->{'format'} = 'cisco' unless $config->{'format'};
  my $self = bless $config, $class;
  $self->{'exec'} = "$self->{'path'} -h $self->{'host'}:$self->{'port'} -APs";
  return $self;
}

sub prefixList {
  my $self = shift;
  my $object = shift;
  my $ver = shift;
  my $max_len = shift;
  my $strict = shift;
  my $entries = [];
  my $exec = "$self->{'exec'} -$ver -l $object -m $max_len ";
  if ($strict) {
    $exec .= "$object";
  } else {
    $exec .= "-R $max_len $object";
  }
  chomp (@$entries = qx/$exec/);
  @$entries = grep(/^ip(v6)? prefix-list $object seq \d+ permit/, @$entries);
  return $entries;
}

return 1;

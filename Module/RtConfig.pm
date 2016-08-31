#!/usr/bin/perl
#
package Module::RtConfig;
use Data::Dumper;

sub new {
  my $class = shift;
  my $config = shift;
  $config->{'path'} = '/usr/local/bin/RtConfig' unless $config->{'path'};
  $config->{'host'} = 'whois.radb.net' unless $config->{'host'};
  $config->{'port'} = 43 unless $config->{'port'};
  $config->{'protocol'} = 'irrd' unless $config->{'protocol'};
  $config->{'format'} = 'cisco' unless $config->{'format'};
  my $self = bless $config, $class;
  $self->{'exec'} = " | $self->{'path'} -h $self->{'host'} -p $self->{'port'} -protocol $self->{'protocol'} -config $self->{'format'}";
  return $self;
}

sub call {
  my $self = shift;
  my $cmd = shift;
  my $exec = "echo '$cmd' | $self->{'path'} -h $self->{'host'} -p $self->{'port'} -protocol $self->{'protocol'} -config $self->{'format'}";
  my $call = [];
  @$call = qx/$exec/;
  return $call;
}

sub printPrefixes {
  my $self = shift;
  my $args = shift;
  my $format = $args->{'format'};
  my $filter = $args->{'filter'};
  my $prefixes = [];
  my $exec = qq/echo '\@RtConfig printPrefixes "$format" filter $filter' $self->{'exec'}/;
  chomp (@$prefixes = qx/$exec/);
  return $prefixes;
}

sub printPrefixRanges {
  my $self = shift;
  my $args = shift;
  my $format = $args->{'format'};
  my $filter = $args->{'filter'};
  my $ranges = [];
  my $exec = qq/echo '\@RtConfig printPrefixRanges "$format" filter $filter' $self->{'exec'}/;
  chomp (@$ranges = qx/$exec/);
  return $ranges;
}

sub prefixes {
  my $self = shift;
  my $filter = shift;
  my $aggr = shift;
  my $format = '%p/%l/%n/%m\n';
  my $tmps = []; my $prefixes = [];
  if ($aggr) {
    $tmps = $self->printPrefixRanges({format => $format, filter => $filter});
  } else {
    $tmps = $self->printPrefixes({format => $format, filter => $filter});
  }
  for my $p (sort @$tmps) {
    my $tmp = {};
    ($tmp->{'p'}, $tmp->{'l'}, $tmp->{'n'}, $tmp->{'m'}) = split('/', $p);
    push @$prefixes, $tmp;
  }
  return $prefixes;
}   

return 1;  

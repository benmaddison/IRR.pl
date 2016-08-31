#!/usr/bin/perl
#
package Module::Logger;
use Sys::Syslog qw(:standard :macros);
use Term::ANSIColor;

sub new {
  my $class = shift;
  my $config = shift;
  $config->{'ident'} = $PROGRAM_NAME unless $config->{'ident'};
  $config->{'facility'} = 'local0' unless $config->{'facility'};
  $config->{'options'} = '' unless $config->{'options'};
  $config->{'level'} = LOG_INFO unless $config->{'level'};
  my $self = bless $config, $class;
  openlog($self->ident(), $self->options(), $self->facility());
  setlogmask( LOG_UPTO($self->level()) );
  $self->log(LOG_INFO, "LOGGER: Logging started to " . $self->facility() . " at level " . $self->level());
  return $self;
}

sub reopen {
  my $self = shift;
  closelog()
    and openlog($self->ident(), $self->options(), $self->facility())
    and setlogmask( LOG_UPTO($self->level()) );
  $self->log(LOG_INFO, "LOGGER: Log restarted to " . $self->facility() . " at level " . $self->level());
  return $self;
}

sub log {
  my $self = shift;
  my $level = shift;
  my $msg = shift;
  syslog($level, $msg);
  return $self;
}

sub ident {
  my $self = shift;
  my $ident = shift;
  if ($ident) {
    $self->log(LOG_INFO, "LOGGER: changing syslog identity to $ident");
    $self->{'ident'} = $ident;
    $self->reopen();
  } else {
    return $self->{'ident'};
  }
  return 0;
}

sub facility {
  my $self = shift;
  my $facility = shift;
  if ($facility) {
    $self->log(LOG_INFO, "LOGGER: changing syslog facility to $facility");
    $self->{'facility'} = $facility;
    $self->reopen();
    return $self;
  } else {
    return $self->{'facility'};
  }
  return 0;
}

sub options {
  my $self = shift;
  my $options  = shift;
  if ($options) {
    $self->log(LOG_INFO, "LOGGER: changing syslog options to $options");
    $self->{'options'} = $options;
    $self->reopen();
    return $self;
  } else {
    return $self->{'options'};
  }
  return 0;
}

sub level {
  my $self = shift;
  my $level = shift;
  if ($level) {
    $self->log(LOG_INFO, "LOGGER: setting loglevel to $level");
    $self->{'level'} = $level;
    setlogmask( LOG_UPTO($self->level()) );
    return $self;
  } else {
    return $self->{'level'};
  }
  return 0;
}

sub colorlog {
  my $self = shift;
  my $level = shift;
  my $msg = shift;
  my $color = shift;
  $msg = colored [$color], $msg;
  $self->log($level, $msg);
  return $self;
}

sub debug {
  my $self = shift;
  my $msg = shift;
  $self->log(LOG_DEBUG, $msg);
  return $self;
}

sub info {
  my $self = shift;
  my $msg = shift;
  $self->log(LOG_INFO, $msg);
  return $self;
}

sub notice {
  my $self = shift;
  my $msg = shift;
  $self->log(LOG_NOTICE, $msg);
  return $self;
}

sub warning {
  my $self = shift;
  my $msg = shift;
  $self->log(LOG_WARNING, $msg);
  return $self;
}

sub err {
  my $self = shift;
  my $msg = shift;
  $self->log(LOG_ERR, $msg);
  return $self;
}

sub crit {
  my $self = shift;
  my $msg = shift;
  $self->log(LOG_CRIT, $msg);
  return $self;
}

sub alert {
  my $self = shift;
  my $msg = shift;
  $self->log(LOG_ALERT, $msg);
  return $self;
}

sub emerg {
  my $self = shift;
  my $msg = shift;
  $self->log(LOG_EMERG, $msg);
  return $self;
}

sub test {
  my $self = shift;
  my $test = shift;
  my $msg = shift;
  my $severity = shift;#// {true => LOG_INFO, false => LOG_WARNING};
  if ($test) {
    $self->{'result'} = 1;
    $self->log($severity->{'true'}, $msg->{'true'});
  } else {
    $self->{'result'} = 0;
    $self->log($severity->{'false'}, $msg->{'false'});
  }
  return $self;
}

sub result {
  my $self = shift;
  my $result = $self->{'result'};
  return $result;
}
     
return 1;

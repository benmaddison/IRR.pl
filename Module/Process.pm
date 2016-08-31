#!/usr/bin/perl
#
package Module::Process;
use POSIX;

sub Daemonize {
  my $config = shift;
  POSIX::setsid or die "setsid: $!";
  my $pid = fork ();
  if ($pid < 0) {
    die "fork: $!";
  } elsif ($pid) {
    open ( PID, ">$config->{'pid_file'}" );
    print PID $pid;
    close PID;
    exit 0;
  }
  chdir $config->{'working_dir'};
  umask 0;
  for my $f (0 .. (POSIX::sysconf (&POSIX::_SC_OPEN_MAX) || 1024))
    { POSIX::close $f }
  open (STDIN, "$config->{'stdin'}");
  open (STDOUT, "$config->{'stdout'}");
  open (STDERR, "$config->{'stderr'}");
  return $$;
}

return 1;

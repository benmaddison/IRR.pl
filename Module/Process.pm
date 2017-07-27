#!/usr/bin/perl
#
package Module::Process;
use POSIX;

sub Daemonize {
  my $config = shift;
  # get uid and gid
  $uid = getpwnam($config->{'user'}) or die "get uid failed: $!";
  $gid = getgrnam($config->{'group'}) or die "get gid failed: $!";
  # check that we are not already running
  if (open(PID, "<$config->{'pid_file'}")) {
    chomp(my $old_pid = <PID>);
    if (kill 0, $old_pid) {
      die "an instance is already running";
    } else {
      unlink $config->{'pid_file'};
    }
    close PID;
  }
  # daemonize...
  POSIX::setsid or die "setsid: $!";
  my $pid = fork ();
  if ($pid < 0) {
    die "fork: $!";
  } elsif ($pid) {
    open(PID, ">$config->{'pid_file'}")
      or die "can't open $config->{'pid_file'} for write: $!";
    print PID $pid;
    close PID;
    exit 0;
  }
  chdir $config->{'working_dir'};
  umask 0;
  for my $f (0 .. (POSIX::sysconf (&POSIX::_SC_OPEN_MAX) || 1024))
    { POSIX::close $f }
  POSIX::setgid($gid) or die "setgid: $!";
  POSIX::setuid($uid) or die "setuid: $!";
  open(STDIN, "<$config->{'stdin'}")
    or die "can't open $config->{'stdin'} for read: $!";
  open (STDOUT, ">>$config->{'stdout'}")
    or die "can't open $config->{'stdout'} for write: $!";
  open (STDERR, ">>$config->{'stderr'}")
    or die "can't open $config->{'stderr'} for write: $!";
  return $$;
}

return 1;

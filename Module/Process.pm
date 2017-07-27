#!/usr/bin/perl
#
package Module::Process;
use POSIX;

sub Daemonize {
  my $config = shift;
  my $pid_dir = shift;
  # get uid and gid
  $uid = getpwnam($config->{'user'}) or die "get uid failed: $!";
  $gid = getgrnam($config->{'group'}) or die "get gid failed: $!";
  # check that we are not already running
  my $pid_file = "$pid_dir/IRR.pid";
  if (open(PID, "<$pid_file")) {
    chomp(my $old_pid = <PID>);
    if (kill 0, $old_pid) {
      die "an instance is already running";
    } else {
      unlink $pid_file;
    }
    close PID;
  }
  # daemonize...
  POSIX::setsid or die "setsid: $!";
  my $pid = fork ();
  if ($pid < 0) {
    die "fork: $!";
  } elsif ($pid) {
    open(PID, ">$pid_file")
      or die "can't open $pid_file for write: $!";
    print PID $pid;
    close PID;
    exit 0;
  }
  chdir $config->{'working_dir'};
  umask 0;
  for my $f (0 .. (POSIX::sysconf (&POSIX::_SC_OPEN_MAX) || 1024))
    { POSIX::close $f }
  # drop privileges
  POSIX::setgid($gid) or die "setgid: $!";
  POSIX::setuid($uid) or die "setuid: $!";
  # reopen stdin/stdout/stderr
  open(STDIN, "</dev/null") or die "can't open /dev/null for read: $!";
  open(STDOUT, ">/dev/null") or die "can't open /dev/null for write: $!";
  open(STDERR, ">/dev/null") or die "can't open /dev/null for write: $!";
  return $$;
}

return 1;

package Classes::APC::Powermib::Components::EnvironmentalSubsystem;
our @ISA = qw(Classes::APC::Powermib);
use strict;
use POSIX qw(mktime);

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my $self = shift;
  $self->get_snmp_objects('PowerNet-MIB', (qw(
      upsBasicIdentModel 
      upsAdvIdentDateOfManufacture upsAdvIdentSerialNumber
      upsAdvTestDiagnosticSchedule
      upsAdvTestDiagnosticsResults upsAdvTestLastDiagnosticsDate)));
  eval {
    die if ! $self->{upsAdvTestLastDiagnosticsDate};
    $self->{upsAdvTestLastDiagnosticsDate} =~ /(\d+)\/(\d+)\/(\d+)/;
    $self->{upsAdvTestLastDiagnosticsDate} = mktime(0, 0, 0, $2, $1 - 1, $3 - 1900);
    $self->{upsAdvTestLastDiagnosticsAge} = (time - $self->{upsAdvTestLastDiagnosticsDate}) / (3600 * 24);
  };
  if ($@) {
    $self->{upsAdvTestLastDiagnosticsDate} = 0;
  }
}

sub check {
  my $self = shift;
  my $info = undef;
  $self->add_info('checking hardware and self-tests');
  if ($self->{upsAdvTestLastDiagnosticsDate}) {
    $info = sprintf 'selftest result was %s',
        $self->{upsAdvTestDiagnosticsResults};
    $self->add_info($info);
    if ($self->{upsAdvTestDiagnosticsResults} ne 'ok') {
      $self->add_warning($info);
    } else {
      $self->add_ok($info);
    } 
    my $maxage = undef;
    if ($self->{upsAdvTestDiagnosticSchedule} eq 'never') {
      $maxage = 365;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'biweekly') {
      $maxage = 14;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'weekly') {
      $maxage = 7;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'fourWeeks') {
      $maxage = 28;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'twelveWeeks') {
      $maxage = 84;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'biweeklySinceLastTest') {
      $maxage = 14;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'weeklySinceLastTest') {
      $maxage = 7;
    }
    if (! defined $maxage && $self->{upsAdvTestDiagnosticSchedule} ne 'never') {
      $self->set_thresholds(
          metric => 'selftest_age', warning => '30', critical => '60');
    } else {
      $maxage *= 2; # got lots of alerts from my test devices
      $self->set_thresholds(
          metric => 'selftest_age', warning => $maxage, critical => $maxage);
    }
    $info = sprintf 'last selftest was %d days ago (%s)', $self->{upsAdvTestLastDiagnosticsAge}, scalar localtime $self->{upsAdvTestLastDiagnosticsDate};
    $self->add_info($info);
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsAdvTestLastDiagnosticsAge},
            metric => 'selftest_age'), $info);
    $self->add_perfdata(
        label => 'selftest_age',
        value => $self->{upsAdvTestLastDiagnosticsAge},
        warning => ($self->get_thresholds(metric => 'selftest_age'))[0],
        critical => ($self->get_thresholds(metric => 'selftest_age'))[1],
    );
  } else {
    $self->add_ok("hardware working fine, at least i hope so, because self-tests were never run");
  }
}

sub dump {
  my $self = shift;
  printf "[HARDWARE]\n";
  foreach (qw(upsBasicIdentModel 
      upsAdvIdentDateOfManufacture upsAdvIdentSerialNumber
      upsAdvTestDiagnosticSchedule
      upsAdvTestDiagnosticsResults upsAdvTestLastDiagnosticsDate)) {
    printf "%s: %s\n", $_, $self->{$_} if defined $self->{$_};
    printf "%s: %s\n", $_, scalar localtime $self->{$_} if (defined $self->{$_} && $_ =~ /Date$/);
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}

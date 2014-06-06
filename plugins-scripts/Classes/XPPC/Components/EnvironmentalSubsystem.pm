package Classes::XPPC::Components::EnvironmentalSubsystem;
our @ISA = qw(Classes::XPPC);
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
  $self->get_snmp_objects('XPPC-MIB', (qw(upsSmartTestDiagnosticSchedule
      upsSmartTestDiagnostics upsSmartTestDiagnosticsResults
      upsSmartTestLastDiagnosticsDate upsSmartTestIndicators    upsThreePhaseBatteryGrp
      upsEnvTemperature upsEnvHumidity upsEnvWater upsEnvSmoke 
      upsEnvSecurity1 upsEnvSecurity2 upsEnvSecurity3 upsEnvSecurity4
      upsEnvSecurity5 upsEnvSecurity6 upsEnvSecurity7
      upsEnvOverTemperature upsEnvUnderTemperature upsEnvOverHumidity upsEnvUnderHumidity)));
  eval {
    die if ! $self->{upsSmartTestLastDiagnosticsDate};
    $self->{upsSmartTestLastDiagnosticsDate} =~ /(\d+)\/(\d+)\/(\d+)/;
    $self->{upsSmartTestLastDiagnosticsDate} = mktime(0, 0, 0, $2, $1 - 1, $3 - 1900);
    $self->{upsSmartTestLastDiagnosticsAge} = (time - $self->{upsSmartTestLastDiagnosticsDate}) / (3600 * 24);
  };
  if ($@) {
    $self->{upsSmartTestLastDiagnosticsDate} = 0;
  }

}

sub check {
  my $self = shift;
  $self->add_info('checking hardware and self-tests');
  if ($self->{upsEnvTemperature}) {
    my $over = $self->{upsEnvOverTemperature} || 30;
    my $under = $self->{upsEnvUnderTemperature} || 10;
    $self->set_thresholds(
        metric => 'temperature', warning => $under.':'.$over, critical => $under.':'.$over);
    $self->add_info(sprintf 'temperature is %.2fC', $self->{upsEnvTemperature});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEnvTemperature},
            metric => 'temperature'));
    $self->add_perfdata(
        label => 'temperature',
        value => $self->{upsEnvTemperature},
    );
  }
  if ($self->{upsEnvHumidity}) {
    my $over = $self->{upsEnvOverHumidity} || 50;
    my $under = $self->{upsEnvUnderHumidity} || 12;
    $self->set_thresholds(
        metric => 'humidity', warning => $under.':'.$over, critical => $under.':'.$over);
    $self->add_info(sprintf 'humidity is %.2f%%', $self->{upsEnvHumidity});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEnvHumidity},
            metric => 'humidity'));
    $self->add_perfdata(
        label => 'humidity',
        value => $self->{upsEnvHumidity},
    );
  }
  if ($self->{upsSmartTestLastDiagnosticsDate}) {
    $self->add_info(sprintf 'selftest result was %s', $self->{upsSmartTestDiagnosticsResults});
    if ($self->{upsSmartTestDiagnosticsResults} eq 'failed') {
      $self->add_warning();
    } else {
      $self->add_ok();
    } 
    my $maxage = undef;
    if ($self->{upsSmartTestDiagnosticSchedule} eq 'never') {
      $maxage = 365;
    } elsif ($self->{upsSmartTestDiagnosticSchedule} eq 'biweekly') {
      $maxage = 14;
    } elsif ($self->{upsSmartTestDiagnosticSchedule} eq 'weekly') {
      $maxage = 7;
    }
    if (! defined $maxage && $self->{upsSmartTestDiagnosticSchedule} ne 'never') {
      $self->set_thresholds(
          metric => 'selftest_age', warning => '30', critical => '60');
    } else {
      $maxage *= 2; # got lots of alerts from my test devices
      $self->set_thresholds(
          metric => 'selftest_age', warning => $maxage, critical => $maxage);
    }
    $self->add_info(sprintf 'last selftest was %d days ago (%s)', $self->{upsSmartTestLastDiagnosticsAge}, scalar localtime $self->{upsSmartTestLastDiagnosticsDate});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsSmartTestLastDiagnosticsAge},
            metric => 'selftest_age'));
    $self->add_perfdata(
        label => 'selftest_age',
        value => $self->{upsSmartTestLastDiagnosticsAge},
    );
  } else {
    $self->add_warning("please run diagnostics");
  }
  if (! $self->check_messages()) {
    $self->add_ok("hardware working fine");
  }
}

sub xdump {
  my $self = shift;
  printf "[HARDWARE]\n";
  foreach (qw(upsBasicIdentModel 
      upsAdvIdentDateOfManufacture upsAdvIdentSerialNumber
      upsSmartTestDiagnosticSchedule
      upsAdvTestDiagnosticsResults upsSmartTestLastDiagnosticsDate)) {
    printf "%s: %s\n", $_, $self->{$_} if defined $self->{$_};
    printf "%s: %s\n", $_, scalar localtime $self->{$_} if (defined $self->{$_} && $_ =~ /Date$/);
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}

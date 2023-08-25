package CheckUpsHealth::APC::Powermib::UPS::Component::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;
use POSIX qw(mktime);

sub init {
  my ($self) = @_;
  # aufteilen in eigene packages: basic, advanced und smart
  # wenn adv keine tests hatte, dann upsBasicStateOutputState fragen
  $self->get_snmp_objects('PowerNet-MIB', (qw(
      upsBasicIdentModel 
      upsBasicOutputStatus upsBasicSystemStatus
      upsBasicSystemInternalTemperature
      upsBasicStateOutputState 
      upsAdvIdentDateOfManufacture upsAdvIdentSerialNumber
      upsAdvTestDiagnosticSchedule
      upsAdvTestDiagnosticsResults upsAdvTestLastDiagnosticsDate
      upsAdvStateAbnormalConditions
      upsAdvStateSymmetra3PhaseSpecificFaults
      upsAdvStateDP300ESpecificFaults
      upsAdvStateSymmetraSpecificFaults
      upsAdvStateSmartUPSSpecificFaults
      upsAdvStateSystemMessages
  )));
  eval {
    die if ! $self->{upsAdvTestLastDiagnosticsDate};
    $self->{upsAdvTestLastDiagnosticsDate} =~ /(\d+)\/(\d+)\/(\d+)/ || die;
    $self->{upsAdvTestLastDiagnosticsDate} = mktime(0, 0, 0, $2, $1 - 1, $3 - 1900);
    $self->{upsAdvTestLastDiagnosticsAge} = (time - $self->{upsAdvTestLastDiagnosticsDate}) / (3600 * 24);
  };
  if ($@) {
    $self->{upsAdvTestLastDiagnosticsDate} = 0;
  }
}

sub check {
  my ($self) = @_;
  my $info = undef;
  $self->add_info('checking hardware and self-tests');
  if (defined $self->{upsBasicStateOutputState}) {
    my @bits = split(//, $self->{upsBasicStateOutputState});
    if (scalar(@bits) == 64) {
      $self->add_unknown('status unknown');
    } else {
      $self->add_ok('On Line') if $bits[4];
      #$self->add_ok('Serial Communication Established') if $bits[6];
      #$self->add_ok('On') if $bits[19];
      $self->add_warning('Abnormal Condition Present') if $bits[1];
      $self->add_warning('Electronic Unit Fan Failure') if $bits[41];
      $self->add_warning('Main Relay Failure') if $bits[42];
      $self->add_warning('Bypass Relay Failure') if $bits[43];
      $self->add_warning('High Internal Temperature') if $bits[45];
      $self->add_warning('Battery Temperature Sensor Fault') if $bits[46];
      $self->add_warning('PFC Failure') if $bits[49];
      $self->add_critical('Critical Hardware Fault') if $bits[50];
      $self->add_critical('Emergency Power Off (EPO) Activated') if $bits[53];
      $self->add_warning('UPS Internal Communication Failure') if $bits[56];
    }
  }
  if ($self->{upsAdvTestLastDiagnosticsDate}) {
    $self->add_info(sprintf 'selftest result was %s',
        $self->{upsAdvTestDiagnosticsResults});
    if ($self->{upsAdvTestDiagnosticsResults} ne 'ok') {
      $self->add_warning();
    } else {
      $self->add_ok();
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
    $self->add_info(sprintf 'last selftest was %d days ago (%s)', $self->{upsAdvTestLastDiagnosticsAge}, scalar localtime $self->{upsAdvTestLastDiagnosticsDate});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsAdvTestLastDiagnosticsAge},
            metric => 'selftest_age'));
    $self->add_perfdata(
        label => 'selftest_age',
        value => $self->{upsAdvTestLastDiagnosticsAge},
    );
  } else {
    $self->add_ok("hardware working fine, at least i hope so, because self-tests were never run") if ! $self->check_messages();
    $self->add_ok("self-tests were never run") if $self->check_messages();
  }
}


package CheckUpsHealth::APC::Powermib::UPS::Component::EnvironmentalSubsystem::Simple;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

package CheckUpsHealth::APC::Powermib::UPS::Component::EnvironmentalSubsystem::Advanced;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;


package Classes::APC::Powermib::UPS::Components::BatterySubsystem;
our @ISA = qw(Classes::APC::Powermib);
use strict;

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my ($self) = @_;
  $self->get_snmp_objects('PowerNet-MIB', (qw(
      upsBasicBatteryStatus upsAdvBatteryCapacity 
      upsAdvBatteryReplaceIndicator upsAdvBatteryTemperature 
      upsAdvBatteryRunTimeRemaining 
      upsAdvInputLineVoltage upsAdvInputFrequency 
      upsAdvInputMaxLineVoltage upsAdvInputMinLineVoltage 
      upsAdvOutputVoltage upsAdvOutputFrequency 
      upsBasicOutputStatus upsAdvOutputLoad upsAdvOutputCurrent
      upsHighPrecOutputLoad  
      upsAdvInputLineFailCause)));
  $self->{upsAdvBatteryRunTimeRemaining} = $self->{upsAdvBatteryRunTimeRemaining} / 6000;
  # beobachtet bei Smart-Classes RT 1000 RM XL, da gab's nur
  # upsAdvOutputVoltage und upsAdvOutputFrequency
  $self->{upsAdvOutputLoad} = 
      ! defined $self->{upsAdvOutputLoad} || $self->{upsAdvOutputLoad} eq '' ?
      $self->{upsHighPrecOutputLoad} / 10 : $self->{upsAdvOutputLoad};
  # wer keine Angaben macht, gilt als gesund.
  $self->{upsBasicBatteryStatus} ||= 'batteryNormal';
}

sub check {
  my ($self) = @_;
  $self->add_info('checking battery');
  $self->add_info(sprintf 'battery status is %s',
      $self->{upsBasicBatteryStatus});
  if ($self->{upsBasicBatteryStatus} ne 'batteryNormal') {
    $self->add_critical();
  } else {
    $self->add_ok();
  } 
  if ($self->{upsAdvBatteryReplaceIndicator} && $self->{upsAdvBatteryReplaceIndicator} eq 'batteryNeedsReplacing') {
    $self->add_critical('battery needs replacing');
  }
  if ($self->{upsBasicOutputStatus}) { # kann auch undef sein (10kv z.b.)
    if ($self->{upsBasicOutputStatus} eq 'onBattery' &&
        $self->{upsAdvInputLineFailCause} eq 'selfTest') {
      $self->add_ok(sprintf 'output status is %s',
          $self->{upsBasicOutputStatus});
      $self->add_ok(sprintf 'caused by %s',
          $self->{upsAdvInputLineFailCause});
    } elsif ($self->{upsBasicOutputStatus} ne 'onLine') {
      $self->add_warning(sprintf 'output status is %s',
          $self->{upsBasicOutputStatus});
      $self->add_warning(sprintf 'caused by %s',
          $self->{upsAdvInputLineFailCause});
    }
  }

  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  my ($warn, $crit) = $self->get_thresholds(metric => 'capacity');
  if ($self->{upsBasicOutputStatus} and
      $self->{upsBasicOutputStatus} eq 'onBattery' and
      $self->{upsAdvInputLineFailCause} eq 'selfTest') {
    # Schwellwerte halbieren, da beim Selbsttest durchaus ein paar Prozent
    # verloren gehen.
    (my $nwarn = $warn) =~ s/:$//g;
    (my $ncrit = $crit) =~ s/:$//g;
    $nwarn /= 2;
    $ncrit /= 2;
    $warn = $nwarn.':';
    $crit = $ncrit.':';
  }
  $self->add_info(sprintf 'capacity is %.2f%%', $self->{upsAdvBatteryCapacity});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvBatteryCapacity},
          metric => 'capacity',
          warning => $warn,
          critical => $crit));
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{upsAdvBatteryCapacity},
      uom => '%',
      warning => $warn,
      critical => $crit,
  );

  $self->set_thresholds(
      metric => 'output_load', warning => '75', critical => '85');
  $self->add_info(sprintf 'output load %.2f%%', $self->{upsAdvOutputLoad});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvOutputLoad},
          metric => 'output_load'));
  $self->add_perfdata(
      label => 'output_load',
      value => $self->{upsAdvOutputLoad},
      uom => '%',
  );

  $self->set_thresholds(
      metric => 'battery_temperature', warning => '70', critical => '80');
  $self->add_info(sprintf 'temperature is %.2fC', $self->{upsAdvBatteryTemperature});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvBatteryTemperature},
          metric => 'battery_temperature'));
  $self->add_perfdata(
      label => 'battery_temperature',
      value => $self->{upsAdvBatteryTemperature},
  );

  $self->set_thresholds(
      metric => 'remaining_time', warning => '10:', critical => '8:');
  $self->add_info(sprintf 'remaining battery run time is %.2fmin', $self->{upsAdvBatteryRunTimeRemaining});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvBatteryRunTimeRemaining},
          metric => 'remaining_time'));
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsAdvBatteryRunTimeRemaining},
  );

  if (defined $self->{upsAdvInputLineVoltage} && $self->{upsAdvInputLineVoltage} < 1 && $self->{upsAdvBatteryCapacity} < 90) {
    # upsAdvInputLineVoltage can be noTransfer after spikes or selftests.
    # this might be tolerable as long as the battery is full.
    # only when external voltage is needed this should raise an alarm
    # (< 100 is not enough, even under normal circumstances the capacity drops
    # below 100)
    $self->add_critical('input power outage');
    if ($self->{upsAdvInputLineFailCause}) {
      $self->add_critical($self->{upsAdvInputLineFailCause});
      if ($self->{upsAdvInputLineFailCause} eq 'noTransfer') {
        $self->add_critical('please repeat self-tests or reboot');
      }
    }
  }
  $self->add_perfdata(
      label => 'input_voltage',
      value => $self->{upsAdvInputLineVoltage},
  ) if defined $self->{upsAdvInputLineVoltage};
  $self->add_perfdata(
      label => 'input_frequency',
      value => $self->{upsAdvInputFrequency},
  ) if defined $self->{upsAdvInputFrequency};
  $self->add_perfdata(
      label => 'output_voltage',
      value => $self->{upsAdvOutputVoltage},
  ) if defined $self->{upsAdvOutputVoltage};;
  $self->add_perfdata(
      label => 'output_frequency',
      value => $self->{upsAdvOutputFrequency},
  ) if defined $self->{upsAdvOutputFrequency};
}

sub dump {
  my ($self) = @_;
  printf "[BATTERY]\n";
  foreach (qw(upsBasicBatteryStatus upsAdvBatteryCapacity 
      upsAdvBatteryReplaceIndicator upsAdvBatteryTemperature 
      upsAdvBatteryRunTimeRemaining 
      upsAdvInputLineVoltage upsAdvInputFrequency 
      upsAdvInputMaxLineVoltage upsAdvInputMinLineVoltage 
      upsAdvOutputVoltage upsAdvOutputFrequency 
      upsBasicOutputStatus upsAdvOutputLoad upsAdvOutputCurrent
      upsAdvInputLineFailCause)) { 
    printf "%s: %s\n", $_, $self->{$_} if defined $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}

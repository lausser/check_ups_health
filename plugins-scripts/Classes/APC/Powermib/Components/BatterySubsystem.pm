package Classes::APC::Powermib::Components::BatterySubsystem;
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
  my $self = shift;
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
}

sub check {
  my $self = shift;
  $self->add_info('checking battery');
  my $info = undef;
  $info = sprintf 'battery status is %s',
      $self->{upsBasicBatteryStatus};
  $self->add_info($info);
  if ($self->{upsBasicBatteryStatus} ne 'batteryNormal') {
    $self->add_critical($info);
  } else {
    $self->add_ok($info);
  } 
  if ($self->{upsAdvBatteryReplaceIndicator} && $self->{upsAdvBatteryReplaceIndicator} eq 'batteryNeedsReplacing') {
    $self->add_critical('battery needs replacing');
  }
  if ($self->{upsBasicOutputStatus} && # kann auch undef sein (10kv z.b.)
      $self->{upsBasicOutputStatus} ne 'onLine') {
    $self->add_warning(sprintf 'output status is %s',
        $self->{upsBasicOutputStatus});
    $self->add_warning(sprintf 'caused by %s',
        $self->{upsAdvInputLineFailCause});
  }

  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  $info = sprintf 'capacity is %.2f%%', $self->{upsAdvBatteryCapacity};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvBatteryCapacity},
          metric => 'capacity'), $info);
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{upsAdvBatteryCapacity},
      uom => '%',
      warning => ($self->get_thresholds(metric => 'capacity'))[0],
      critical => ($self->get_thresholds(metric => 'capacity'))[1],
  );

  $self->set_thresholds(
      metric => 'output_load', warning => '75', critical => '85');
  $info = sprintf 'output load %.2f%%', $self->{upsAdvOutputLoad};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvOutputLoad},
          metric => 'output_load'), $info);
  $self->add_perfdata(
      label => 'output_load',
      value => $self->{upsAdvOutputLoad},
      uom => '%',
      warning => ($self->get_thresholds(metric => 'output_load'))[0],
      critical => ($self->get_thresholds(metric => 'output_load'))[1],
  );

  $self->set_thresholds(
      metric => 'battery_temperature', warning => '70', critical => '80');
  $info = sprintf 'temperature is %.2fC', $self->{upsAdvBatteryTemperature};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvBatteryTemperature},
          metric => 'battery_temperature'), $info);
  $self->add_perfdata(
      label => 'battery_temperature',
      value => $self->{upsAdvBatteryTemperature},
      warning => ($self->get_thresholds(metric => 'battery_temperature'))[0],
      critical => ($self->get_thresholds(metric => 'battery_temperature'))[1],
  );

  $self->set_thresholds(
      metric => 'remaining_time', warning => '10:', critical => '8:');
  $info = sprintf 'remaining battery run time is %.2fmin', $self->{upsAdvBatteryRunTimeRemaining};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvBatteryRunTimeRemaining},
          metric => 'remaining_time'), $info);
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsAdvBatteryRunTimeRemaining},
      warning => ($self->get_thresholds(metric => 'remaining_time'))[0],
      critical => ($self->get_thresholds(metric => 'remaining_time'))[1],
  );

  if (defined $self->{upsAdvInputLineVoltage} && $self->{upsAdvInputLineVoltage} < 1) {
    $self->add_critical('input power outage');
    if ($self->{upsAdvInputLineFailCause}) {
      $self->add_critical($self->{upsAdvInputLineFailCause});
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
  my $self = shift;
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

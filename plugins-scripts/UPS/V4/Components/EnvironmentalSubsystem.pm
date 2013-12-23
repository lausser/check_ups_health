package UPS::V4::Components::EnvironmentalSubsystem;
our @ISA = qw(UPS::V4);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  foreach (qw(dupsEnvTemperature dupsAlarmOverEnvHumidity dupsAlarmEnvRelay1 
      dupsAlarmEnvRelay2 dupsAlarmEnvRelay3 dupsAlarmEnvRelay4 
      dupsEnvHumidity dupsEnvSetTemperatureLimit dupsEnvSetHumidityLimit 
      dupsEnvSetEnvRelay1 dupsEnvSetEnvRelay2 dupsEnvSetEnvRelay3
      dupsEnvSetEnvRelay4 dupsAlarmOverEnvTemperature
      dupsTemperature)) {
    $self->{$_} = $self->get_snmp_object('UPSV4-MIB', $_, 0);
  }
  $self->{dupsEnvTemperature} ||= $self->{dupsTemperature};
  foreach (qw(dupsAlarmDisconnect dupsAlarmBatteryTestFail dupsAlarmFuseFailure dupsAlarmOutputOverload dupsAlarmOutputOverCurrent dupsAlarmInverterAbnormal dupsAlarmRectifierAbnormal dupsAlarmReserveAbnormal dupsAlarmLoadOnReserve dupsAlarmOverTemperature dupsAlarmOutputBad dupsAlarmPowerFail dupsAlarmBypassBad dupsAlarmUPSOff dupsAlarmChargerFail dupsAlarmFanFail dupsAlarmEconomicMode dupsAlarmOutputOff dupsAlarmSmartShutdown dupsAlarmEmergencyPowerOff dupsAlarmBatteryLow dupsAlarmLoadWarning dupsAlarmLoadSeverity dupsAlarmLoadOnBypass dupsAlarmUPSFault dupsAlarmBatteryGroundFault dupsAlarmTestInProgress)) {
    $self->{$_} = $self->get_snmp_object('UPSV4-MIB', $_, 0);
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking environment');
  my $info = sprintf 'temperature %dC',
      $self->{dupsEnvTemperature};
  if ($self->{dupsEnvHumidity}) {
    $info .= sprintf ', humidity %d%%', $self->{dupsEnvHumidity};
  }
  $self->add_message(OK, $info);
  $self->add_info($info);
  my $alarms = 0;
  foreach (qw(dupsAlarmDisconnect dupsAlarmBatteryTestFail dupsAlarmFuseFailure dupsAlarmOutputOverload dupsAlarmOutputOverCurrent dupsAlarmInverterAbnormal dupsAlarmRectifierAbnormal dupsAlarmReserveAbnormal dupsAlarmLoadOnReserve dupsAlarmOverTemperature dupsAlarmOutputBad dupsAlarmPowerFail dupsAlarmBypassBad dupsAlarmUPSOff dupsAlarmChargerFail dupsAlarmFanFail dupsAlarmEconomicMode dupsAlarmOutputOff dupsAlarmSmartShutdown dupsAlarmEmergencyPowerOff dupsAlarmBatteryLow dupsAlarmLoadWarning dupsAlarmLoadSeverity dupsAlarmLoadOnBypass dupsAlarmUPSFault dupsAlarmBatteryGroundFault dupsAlarmTestInProgress)) {
    if ($self->{$_} && $self->{$_} eq 'on') {
      $self->add_message(CRITICAL, sprintf 'alarm %s is on', $_);
      $alarms++;
    }
  }
  if ($self->{dupsAlarmOverEnvTemperature} eq 'on') {
    $self->add_message(CRITICAL, sprintf 'temperature too high, %d max',
        $self->{dupsEnvSetTemperatureLimit});
    $alarms++;
  }
  if ($self->{dupsAlarmOverEnvHumidity} eq 'on') {
    $self->add_message(CRITICAL, sprintf 'humidity too high, %d max',
        $self->{dupsEnvSetHumidityLimit});
    $alarms++;
  }
  if (! $alarms) {
    $self->add_message(OK, 'no alarms');
  }
  $self->add_perfdata(
      label => 'temperature',
      value => $self->{dupsEnvTemperature},
  );
  if ($self->{dupsEnvHumidity}) {
    $self->add_perfdata(
        label => 'humidity',
        value => $self->{dupsEnvHumidity},
        uom => '%',
    );
  }
}

sub dump {
  my $self = shift;
  printf "[HARDWARE]\n";
  foreach (qw(dupsEnvTemperature dupsAlarmOverEnvHumidity dupsAlarmEnvRelay1 
      dupsAlarmEnvRelay2 dupsAlarmEnvRelay3 dupsAlarmEnvRelay4 
      dupsEnvHumidity dupsEnvSetTemperatureLimit dupsEnvSetHumidityLimit 
      dupsEnvSetEnvRelay1 dupsEnvSetEnvRelay2 dupsEnvSetEnvRelay3
      dupsEnvSetEnvRelay4 dupsAlarmOverEnvTemperature)) {
    printf "%s: %s\n", $_, defined $self->{$_} ? $self->{$_} : 'undefined';
  }
  foreach (qw(dupsAlarmDisconnect dupsAlarmBatteryTestFail dupsAlarmFuseFailure dupsAlarmOutputOverload dupsAlarmOutputOverCurrent dupsAlarmInverterAbnormal dupsAlarmRectifierAbnormal dupsAlarmReserveAbnormal dupsAlarmLoadOnReserve dupsAlarmOverTemperature dupsAlarmOutputBad dupsAlarmPowerFail dupsAlarmBypassBad dupsAlarmUPSOff dupsAlarmChargerFail dupsAlarmFanFail dupsAlarmEconomicMode dupsAlarmOutputOff dupsAlarmSmartShutdown dupsAlarmEmergencyPowerOff dupsAlarmBatteryLow dupsAlarmLoadWarning dupsAlarmLoadSeverity dupsAlarmLoadOnBypass dupsAlarmUPSFault dupsAlarmBatteryGroundFault dupsAlarmTestInProgress)) {
    printf "%s: %s\n", $_, defined $self->{$_} ? $self->{$_} : 'undefined';
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}

package Classes::XUPS::Components::EnvironmentalSubsystem;
our @ISA = qw(Classes::XUPS);
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
  $self->get_snmp_objects("XUPS-MIB", qw(xupsAlarmNumEvents));
  $self->get_snmp_tables("XUPS-MIB", [
      ["alarms", "xupsAlarmTable", "Classes::XUPS::Components::EnvironmentalSubsystem::Alarm"],
  ]);
}

sub check {
  my $self = shift;
  $self->add_info('checking alarms');
  foreach (@{$self->{alarms}}) {
    $_->check();
  }
  if (! $self->check_messages()) {
    $self->add_ok("hardware working fine. no alarms");
  }
}

sub dump {
  my $self = shift;
  printf "[ALARMS]\n";
  foreach (grep /^xups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
  foreach (@{$self->{alarms}}) {
    $_->dump();
  }
}


package Classes::XUPS::Components::EnvironmentalSubsystem::Alarm;
our @ISA = qw(GLPlugin::SNMP::TableItem);
use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub check {
  my $self = shift;
  foreach (qw(xupsOnBattery xupsLowBattery xupsUtilityPowerRestored xupsReturnFromLowBattery 
      xupsOutputOverload xupsInternalFailure xupsBatteryDischarged xupsInverterFailure 
      xupsOnBypass xupsBypassNotAvailable xupsOutputOff xupsInputFailure 
      xupsBuildingAlarm xupsShutdownImminent xupsOnInverter)) {
    if ($self->{xupsAlarmDescr} eq  $GLPlugin::SNMP::mibs_and_oids->{"XUPS-MIB"}->{$_}) {
      $self->{xupsAlarmDescr} = $_;
    }
  }
  my $age = $GLPlugin::SNMP::uptime - $self->{xupsAlarmTime};
  if ($age < 3600) {
    $self->add_critical(sprintf "alarm: %s (%d min ago)",
        $self->{xupsAlarmDescr}, $age / 60);
  }
}

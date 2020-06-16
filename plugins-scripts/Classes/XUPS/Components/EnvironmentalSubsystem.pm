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
  my ($self) = @_;
  $self->get_snmp_objects("XUPS-MIB", qw(xupsAlarmNumEvents
      xupsEnvAmbientTemp xupsEnvAmbientLowerLimit xupsEnvAmbientUpperLimit
      xupsEnvAmbientHumidity
      xupsEnvRemoteTemp xupsEnvRemoteHumidity
      xupsEnvRemoteTempLowerLimit xupsEnvRemoteTempUpperLimit
      xupsEnvRemoteHumidityLowerLimit xupsEnvRemoteHumidityUpperLimit));
  $self->get_snmp_tables("XUPS-MIB", [
      ["alarms", "xupsAlarmTable", "Classes::XUPS::Components::EnvironmentalSubsystem::Alarm"],
  ]);
}

sub upper_lower_limit {
  my $self = shift;
  my ($lower, $upper) = @_;
  my $range = (defined $lower ? $lower : "").":".(defined $upper ? $upper : "");
  return $range eq ":" ? undef : $range;
}

sub check {
  my ($self) = @_;
  $self->add_info('checking alarms');
  foreach (@{$self->{alarms}}) {
    $_->check();
  }
  if ($self->{xupsEnvAmbientTemp}) {
    if (my $range = $self->upper_lower_limit($self->{xupsEnvAmbientLowerLimit}, $self->{xupsEnvAmbientUpperLimit})) {
      $self->set_thresholds(metric => 'ambient_temperature',
          warning => "",
          critical => $range,
      );
    }
    $self->add_perfdata(label => 'ambient_temperature',
        value => $self->{xupsEnvAmbientTemp});
  }
  if ($self->{xupsEnvAmbientHumidity}) {
    $self->add_perfdata(label => 'ambient_humidity',
        value => $self->{xupsEnvAmbientHumidity},
        uom => '%');
  }
  if ($self->{xupsEnvRemoteTemp}) {
    if (my $range = $self->upper_lower_limit($self->{xupsEnvRemoteTempLowerLimit}, $self->{xupsEnvRemoteTempUpperLimit})) {
      $self->set_thresholds(metric => 'remote_temperature',
          warning => "",
          critical => $range,
      );
    }
    $self->add_perfdata(label => 'remote_temperature',
        value => $self->{xupsEnvRemoteTemp});
  }
  if ($self->{xupsEnvRemoteHumidity}) {
    if (my $range = $self->upper_lower_limit($self->{xupsEnvRemoteHumidityLowerLimit}, $self->{xupsEnvRemoteHumidityUpperLimit})) {
      $self->set_thresholds(metric => 'remote_humidity',
          warning => "",
          critical => $range,
      );
    }
    $self->add_perfdata(label => 'remote_humidity',
        value => $self->{xupsEnvRemoteHumidity},
        uom => '%');
  }
  if (! $self->check_messages()) {
    $self->add_ok("hardware working fine");
  }
}

sub dump {
  my ($self) = @_;
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
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub check {
  my ($self) = @_;
  my $age = $self->uptime() - $self->{xupsAlarmTime};
  # xupsAlarmDescr: xupsUtilityPowerRestored
  # xupsAlarmTime: 723852361
  # CRITICAL - alarm: xupsUtilityPowerRestored (-11941630 min ago)
  if ($age < 3600 && $age >= 0) {
    if ($self->{xupsAlarmDescr} =~ /(xupsOutputOffAsRequested|xupsAlarmTestInProgress|xupsOnMaintenanceBypass)/) {
      $self->add_ok('no serious alarms');
    } else {
      $self->add_critical(sprintf "alarm: %s (%d min ago)",
          $self->{xupsAlarmDescr}, $age / 60);
    }
  }
}

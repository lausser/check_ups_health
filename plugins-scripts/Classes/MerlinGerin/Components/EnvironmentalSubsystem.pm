package Classes::MerlinGerin::Components::EnvironmentalSubsystem;
our @ISA = qw(Classes::MerlinGerin);
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
  $self->get_snmp_objects("MGSNMPUPSMIB", qw(
      upsmgConfigEmergencyTestFail upsmgConfigEmergencyOnByPass
      upsmgConfigEmergencyOverload
  ));
  $self->get_snmp_objects("MGSNMPUPSMIB", qw(
   upsmgTestBatterySchedule
   upsmgTestDiagnostics
   upsmgTestDiagResult
   upsmgTestBatteryCalibration
   upsmgTestLastCalibration
   upsmgTestIndicators
   upsmgTestCommandLine
   upsmgTestCommandReady
   upsmgTestResponseLine
   upsmgTestResponseReady
   upsmgTestBatteryResult 
  ));
  $self->get_snmp_tables("MGSNMPUPSMIB", [
      ["environsensors", "upsmgEnvironSensorTable", "Classes::MerlinGerin::Components::EnvironmentalSubsystem::EnvironSensor"],
  ]);
  $self->get_snmp_tables("MGSNMPUPSMIB", [
      ["environmentsensors", "upsmgEnvironmentSensorTable", "Classes::MerlinGerin::Components::EnvironmentalSubsystem::EnvironmentSensor"],
  ]);
  $self->get_snmp_tables("MGSNMPUPSMIB", [
      ["sensorconfigs", "upsmgConfigEnvironmentTable", "Classes::MerlinGerin::Components::EnvironmentalSubsystem::SensorConfig"],
  ]);
  foreach my $es (@{$self->{environmentsensors}}) {
    foreach my $sc (@{$self->{sensorconfigs}}) {
      if ($sc->{upsmgConfigSensorIndex} == $es->{upsmgEnvironmentIndex}) {
        foreach my $k (keys %{$sc}) {
          $es->{$k} = $sc->{$k};
        }
      }
    }
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking environment');
  if (defined $self->{upsmgTestDiagResult} &&
      $self->{upsmgTestDiagResult} eq "failed") {
    # manche haben kein 1.3.6.1.4.1.705.1.10
    $self->add_critical("automatic test diagnostic failed");
  }
  if (! $self->check_messages()) {
    $self->add_ok("hardware working fine");
  }
}

sub dump {
  my $self = shift;
  printf "[SENSORS]\n";
  foreach (@{$self->{environsensors}}) {
    $_->dump();
  }
  foreach (@{$self->{environmentsensors}}) {
    $_->dump();
  }
  foreach (@{$self->{sensorconfigs}}) {
    $_->dump();
  }
  foreach (qw(upsmgConfigEmergencyTestFail upsmgConfigEmergencyOnByPass
      upsmgConfigEmergencyOverload upsmgTestBatterySchedule
      upsmgTestDiagnostics upsmgTestDiagResult
      upsmgTestBatteryCalibration upsmgTestLastCalibration
      upsmgTestIndicators upsmgTestCommandLine
      upsmgTestCommandReady upsmgTestResponseLine
      upsmgTestResponseReady upsmgTestBatteryResult 
  )){
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "\n";
}


package Classes::MerlinGerin::Components::EnvironmentalSubsystem::EnvironSensor;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my $self = shift;
  return;
}


package Classes::MerlinGerin::Components::EnvironmentalSubsystem::SensorConfig;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;


package Classes::MerlinGerin::Components::EnvironmentalSubsystem::EnvironmentSensor;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my $self = shift;
  if ($self->{upsmgEnvironmentComFailure} eq "yes") {
    $self->add_info("no environment module is installed");
  } else {
    foreach my $cat (qw(Temperature Humidity)) {
      if ($cat eq "Humidity" && $self->{'upsmgEnvironment'.$cat} == 0) {
        # kein feuchtesensor verbaut
        next;
      }
      foreach my $thres (qw(High Low)) {
        if ($self->{'upsmgEnvironment'.$cat.$thres} eq "yes") {
          $self->add_critical(sprintf "%s (%.2f) is too %s",
              lc $cat, $self->{'upsmgEnvironment'.$cat}, lc $thres);
        }
      }
      $self->add_perfdata(
          label => lc $cat,
          value => $self->{'upsmgEnvironment'.$cat},
          warning => $self->{'upsmgEnvironment'.$cat.'High'} - $self->{'upsmgConfig'.$cat.'High'},
          critical => $self->{'upsmgEnvironment'.$cat.'High'},
      );
    }
  }
}



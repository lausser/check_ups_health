package CheckUpsHealth::Eaton::ATS2::Component::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects("EATON-ATS2-MIB", qw(ats2IdentManufacturer ats2IdentModel
      ats2IdentFWVersion ats2IdentRelease ats2IdentSerialNumber ats2IdentPartNumber
      ats2IdentAgentVersion
      ats2EnvRemoteTemp ats2EnvRemoteHumidity
      ats2EnvRemoteTempLowerLimit ats2EnvRemoteTempUpperLimit
      ats2EnvRemoteHumidityLowerLimit ats2EnvRemoteHumidityUpperLimit
      ats2StatusInternalFailure ats2StatusOutput ats2StatusOverload
      ats2StatusOverTemperature ats2StatusShortCircuit ats2StatusCommunicationLost
      ats2StatusConfigurationFailure
  ));
  $self->get_snmp_objects("UPS-MIB", qw(upsAlarmsPresent));
}

sub check {
  my ($self) = @_;
#  my $age = $self->uptime() - $self->{upsAlarmTime};
#  if ($age < 3600) {
#    if ($self->{upsAlarmDescr} !~ /(upsAlarmTestInProgress|.*AsRequested)/) {
#      $self->add_critical(sprintf "alarm: %s (%d min ago)",
#          $self->{upsAlarmDescr}, $age / 60);
#    }
#  }
  if ($self->{upsAlarmsPresent}) {
    $self->add_critical("alarm(s) found");
  }
  if (defined $self->{ats2EnvRemoteTemp}) {
    $self->{ats2EnvRemoteTempLowerLimit} ||= -10;
    $self->{ats2EnvRemoteTempUpperLimit} ||= 50;
    $self->set_thresholds(metric => "remote_temp",
        warning => $self->{ats2EnvRemoteTempLowerLimit}.":".$self->{ats2EnvRemoteTempUpperLimit},
    );
    $self->add_message($self->check_thresholds(metric => "remote_temp",
        value => $self->{ats2EnvRemoteTemp}));
  }
  if (defined $self->{ats2EnvRemoteHumidity}) {
    $self->{ats2EnvRemoteHumidityLowerLimit} ||= 30;
    $self->{ats2EnvRemoteHumidityUpperLimit} ||= 70;
    $self->set_thresholds(metric => "remote_hum",
        warning => $self->{ats2EnvRemoteHumidityLowerLimit}.":".$self->{ats2EnvRemoteHumidityUpperLimit},
    );
    $self->add_message($self->check_thresholds(metric => "remote_hum",
        value => $self->{ats2EnvRemoteHumidity}));
  }
  if (defined $self->{ats2StatusInternalFailure}) {
    $self->add_info("ats2StatusInternalFailure is ".$self->{ats2StatusInternalFailure});
    $self->add_critical() if $self->{ats2StatusInternalFailure} ne "good";
  }
  if (defined $self->{ats2StatusOutput}) {
    $self->add_info("ats2StatusOutput is ".$self->{ats2StatusOutput});
    $self->add_critical() if $self->{ats2StatusOutput} ne "outputPowered";
  }
  if (defined $self->{ats2StatusOverload}) {
    $self->add_info("ats2StatusOverload is ".$self->{ats2StatusOverload});
    $self->add_warning() if $self->{ats2StatusOverload} eq "warningOverload";
    $self->add_critical() if $self->{ats2StatusOverload} eq "criticalOverload";
  }
  if (defined $self->{ats2StatusOverTemperature}) {
    $self->add_info("ats2StatusOverTemperature is ".$self->{ats2StatusOverTemperature});
    $self->add_warning() if $self->{ats2StatusOverTemperature} ne "noOverTemperature";
  }
  if (defined $self->{ats2StatusShortCircuit}) {
    $self->add_info("ats2StatusShortCircuit is ".$self->{ats2StatusShortCircuit});
    $self->add_critical() if $self->{ats2StatusShortCircuit} ne "noShortCircuit";
  }
  if (defined $self->{ats2StatusCommunicationLost}) {
    $self->add_info("ats2StatusCommunicationLost is ".$self->{ats2StatusCommunicationLost});
    $self->add_warning() if $self->{ats2StatusCommunicationLost} ne "good";
  }
  if (defined $self->{ats2StatusConfigurationFailure}) {
    $self->add_info("ats2StatusConfigurationFailure is ".$self->{ats2StatusConfigurationFailure});
    $self->add_warning() if $self->{ats2StatusConfigurationFailure} ne "good";
  }
}





























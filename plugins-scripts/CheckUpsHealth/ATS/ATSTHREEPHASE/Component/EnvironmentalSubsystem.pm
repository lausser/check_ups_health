package CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects("ATS-THREEPHASE-MIB", qw(upsUnit1AlarmsPresent
      upsUnit2AlarmsPresent upsUnit3AlarmsPresent upsUnit5AlarmsPresent
      upsUnit5AlarmsPresent upsUnit6AlarmsPresent sysUpsAlarmsPresent
      emdSatatusEmdType emdSatatusTemperature emdSatatusHumidity emdSatatusAlarm1
      emdSatatusAlarm2
  ));

  $self->get_snmp_tables("ATS-THREEPHASE-MIB", [
      ["temperatures", "upsTemperatureGroupTable", "CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::Temperature"],
      ["controls", "upsControlGroupTable", "CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::Control"],
      ["wkstatus", "upsWellKnownStatusTable", "CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::WKStatus"],
      ["wkalarms", "upsWellKnownAlarmTable", "CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::WKAlarm"],
      ["sysalarms", "sysUpsAlarmTable", "CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::SysAlarm"],
      ["syswkalarms", "sysUpsAlarmTable", "CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::SysWKAlarm"],
  ]);
  foreach my $alarmno (1..6) {
    if ($self->{'upsUnit'.$alarmno.'AlarmsPresent'}) {
      $self->get_snmp_tables("ATS-THREEPHASE-MIB", [
          ["alarms".$alarmno, 'upsUnit'.$alarmno.'AlarmsPresent', "CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::Alarm"],
      ]);
    }
  }
}


package CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::Alarm;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  my $age = $self->uptime() - $self->{upsAlarmTime};
  if ($age < 3600) {
    if ($self->{upsAlarmDescr} !~ /(upsAlarmTestInProgress|.*AsRequested)/) {
      $self->add_critical(sprintf "alarm: %s (%d min ago)",
          $self->{upsAlarmDescr}, $age / 60);
    }
  }
}


package CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::Temperature;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  foreach my $key (grep /^upsTemperatureGroup/, keys %{$self}) {
    if ($self->{$key}) {
      $self->{$key} /= 10;
    } else {
      $self->{$key} = 0;
    }
  }
}

sub check {
  my ($self) = @_;
  foreach my $key (grep /^upsTemperatureGroup/, keys %{$self}) {
    if ($key eq "upsTemperatureGroupIndex") {
    } elsif ($self->{$key}) {
      $self->add_perfdata(
          label => $key =~ s/upsTemperatureGroup//r,
          value => $self->{$key},
      );
    }
  }
}

package CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::Control;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

package CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::WKAlarm;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;


sub check {
  my ($self) = @_;
  foreach my $key (grep /^upsWllKnown/, keys %{$self}) {
    if ($self->{$key}) {
      $key =~ s/upsWllKnown//g;
      $self->add_critical(sprintf "Unit %d: %s", $self->{upsWellKnownAlarmId}, $key);
    }
  }
}

package CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::WKStatus;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

package CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::SysAlarm;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

package CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem::SysWKAlarm;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;



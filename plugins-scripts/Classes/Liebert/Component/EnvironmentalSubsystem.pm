package Classes::Liebert::Components::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects("LIEBERT-GP-SYSTEM-MIB", qw(
      lgpSysState
  ));
  $self->get_snmp_objects("LIEBERT-GP-CONDITIONS-MIB", qw(
      lgpConditionsPresent
  ));
  if ($self->{lgpConditionsPresent}) {
    $self->get_snmp_tables("LIEBERT-GP-CONDITIONS-MIB", [
      ["conditions", "lgpConditionsTable", "Classes::Liebert::Components::EnvironmentalSubsystem::Condition"],
    ]);
  }
  if ($self->implements_mib('LIEBERT-GP-ENVIRONMENTAL-MIB')) {
    $self->get_snmp_tables("LIEBERT-GP-ENVIRONMENTAL-MIB", [
      ["temperatures", "lgpEnvTemperatureDegCTable", "Classes::Liebert::Components::EnvironmentalSubsystem::Temperature"],
    ]);
  }
}

sub check {
  my ($self) = @_;
  if (defined $self->{lgpSysState}) {
    if ($self->{lgpConditionsPresent}) {
      $self->{lgpSysState} ||= "errors found";
      $self->add_info(sprintf 'system state is %s', $self->{lgpSysState});
      if ($self->{lgpSysState} eq 'startUp' ||
          $self->{lgpSysState} eq 'normalOperation') {
        $self->add_ok();
      } elsif ($self->{lgpSysState} eq 'normalWithWarning') {
        $self->add_warning();
      } else {
        $self->add_critical();
      }
    } else {
      $self->add_info('lgpConditionsPresent false');
    }
  } else {
    # soll's die UPS-MIB richten
  }
  foreach (@{$self->{conditions}}) {
    $_->check();
  }
  foreach (@{$self->{temperatures}}) {
    $_->check();
  }
}


package Classes::Liebert::Components::EnvironmentalSubsystem::Condition;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{lgpConditionEventTime} = time - $self->ago_sysuptime($self->{lgpConditionTime});
  $self->{lgpConditionEventTimeHuman} = scalar localtime time - $self->ago_sysuptime($self->{lgpConditionTime});
}

sub check {
  my ($self) = @_;
  my $age = $self->ago_sysuptime($self->{lgpConditionTime});
  if ($age < 3600) {
    if ($self->{lgpConditionAcknowledged} eq "notAcknowledged" and $self->{lgpConditionCurrentState} eq "active") {
      $self->add_info(sprintf "alarm: %s (%d min ago)",
          $self->{lgpConditionDescr}, $age / 60);
      if ($self->{lgpConditionSeverity} eq "minor") {
        $self->add_warning();
      } elsif ($self->{lgpConditionSeverity} =~ /(major|critical)/) {
        $self->add_critical();
      }
    }
  }
}

package Classes::Liebert::Components::EnvironmentalSubsystem::Temperature;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  if ($self->{lgpEnvTemperatureDescrDegC} =~ /^[\.\d]+$/) {
    $self->{name} = $self->get_symbol(
        "LIEBERT-GP-ENVIRONMENTAL-MIB",
        $self->{lgpEnvTemperatureDescrDegC}
    );
  }
  $self->{name} ||= 'temperature_';
  $self->{name} .= $self->{flat_indices};
  if (! defined $self->{lgpEnvTemperatureMeasurementDegC}) {
    $self->{lgpEnvTemperatureMeasurementDegC} =
        $self->{lgpEnvTemperatureMeasurementTenthsDegC} / 10.0;
  }
}

sub check {
  my ($self) = @_;
  if ($self->{lgpEnvTemperatureMeasurementTenthsDegC} &&
      $self->{lgpEnvTemperatureMeasurementTenthsDegC} ==  2147483647) {
    # Maxint, duerfte ein nicht-existierender Wert sein.
    return;
  }
  $self->add_info(sprintf '%s is %.2fC', $self->{name},
      $self->{lgpEnvTemperatureMeasurementDegC}
  );
  $self->add_ok();
  $self->add_perfdata(
      label => $self->{name},
      value => $self->{lgpEnvTemperatureMeasurementDegC},
  );
}


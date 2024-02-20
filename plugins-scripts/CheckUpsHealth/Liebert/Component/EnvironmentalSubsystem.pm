package CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem;
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
      ["conditions", "lgpConditionsTable", "CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::Condition"],
    ]);
  }
  if ($self->implements_mib('LIEBERT-GP-ENVIRONMENTAL-MIB')) {
    $self->get_snmp_tables("LIEBERT-GP-ENVIRONMENTAL-MIB", [
      ["temperatures", "lgpEnvTemperatureDegCTable", "CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::Temperature", sub { my $o = shift; return $o->{valid}}],
    ]);
  }
  if ($self->implements_mib('LIEBERT-GP-FLEXIBLE-MIB')) {
    # am 17.2.23 liefen ploetzlich hunderte UPS in Timeouts wegen dieser
    # Table lgpFlexibleBasicTable hier.
    # Da sie eh nur wegen TODO abgefragt wurde, fliegt die erstmal
    # raus. (lgpFlexibleExtendedTable ist ebenfalls so eine Bremse)
    # am 19.2.24 wurden Temperaturwerte gewuenscht. UPS-MIB:1.3.6.1.2.1.33.1.2.7 gibts nicht, also muss diese Dreckstable doch noch ran.
    # Erstmal mit Fingerspitzen die Label holen, und indices der
    # temperature-relevanten Zeilen weiterbenutzen.
    # Durch Zufall entdeckt am 19.2.24: wenn man max_msg_size
    # aufdreht, dann werden aus >100s ploetzlich < 10s
    $self->reset_snmp_max_msg_size();
    # Messungen mit 1..100 haben gezeigt, daß es bei 11 drastisch
    # runtergeht, 105s->5s, ab 20 dann wieder ansteigt.
    $self->mult_snmp_max_msg_size(11);
    $self->get_snmp_tables("LIEBERT-GP-FLEXIBLE-MIB", [
      ["flexentrylabels", "lgpFlexibleExtendedTable", "Monitoring::GLPlugin::SNMP::TableItem", sub {my $o = shift; $o->{lgpFlexibleEntryDataDescription} =~ /battery.*temperature/i;}, ["lgpFlexibleEntryDataDescription"]],
    ]);
    if (@{$self->{flexentrylabels}}) {
      my @indices = map {
          $_->{indices};
      } @{$self->{flexentrylabels}};
      if (@indices) {
        foreach ($self->get_snmp_table_objects("LIEBERT-GP-FLEXIBLE-MIB", "lgpFlexibleExtendedTable", \@indices)) {
          push(@{$self->{flexlabels}},
              CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexTemperature->new(%{$_})) if
            $_->{lgpFlexibleEntryDataDescription} !~ /highest/i and
            $_->{lgpFlexibleEntryUnitsOfMeasureEnum} and
            $_->{lgpFlexibleEntryUnitsOfMeasureEnum} eq "degC";
        }
      }
    }
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
  foreach (@{$self->{flexlabels}}) {
    $_->check();
  }
}


package CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::Condition;
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
  if ($age < 3600*5) {
    # give the service the chance to notify (with a check_interval of 1h)
    # later, ignore these conditions in order not to hide new failures
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

package CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::Temperature;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{valid} = 1;
  if (! defined $self->{lgpEnvTemperatureMeasurementDegC} and
      ! defined $self->{lgpEnvTemperatureMeasurementTenthsDegC}) {
    $self->{valid} = 0;
    return;
  }
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

package CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexTemperature;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{lgpFlexibleEntryValue} = $self->{lgpFlexibleEntryIntegerValue} / 10 ** $self->{lgpFlexibleEntryDecimalPosition};
  # lgpFlexibleEntryDataDescription: The battery temperature for a cabinet
  # kein Ahnung, ob da noch weitere dazukommen koennen, irgendwelche
  # The battery temperature for a splitrolldyx
  # Vorsichtshalber index dahinter
  $self->{name} ||= 'battery_temp_';
  $self->{name} .= $self->{flat_indices};
}

sub check {
  my ($self) = @_;
  if ($self->{lgpFlexibleEntryIntegerValue} &&
      $self->{lgpFlexibleEntryIntegerValue} ==  2147483647) {
    # Maxint, duerfte ein nicht-existierender Wert sein.
    # Weiss nicht, ob das hier vorkommt, in der obigen MIB schon
#    return;
  }
  $self->add_info(sprintf '%s is %.2fC', $self->{name},
      $self->{lgpFlexibleEntryValue}
  );
  $self->add_ok();
  $self->add_perfdata(
      label => $self->{name},
      value => $self->{lgpFlexibleEntryValue},
  );
}


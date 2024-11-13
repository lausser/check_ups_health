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
    # sowas gibt's. kein lgpSysState, aber laut lgpConditionsTable irgendwie
    # falsch verkabelt. an sich wurde das im Liebert.pm an die UPS-MIB
    # weitergereicht, aber besser ist es, hier einen arschtritt auszuteilen.
    $self->{lgpSysState} = "normalWithWarning"
        if ! defined $self->{lgpSysState} and
              grep { not $_->{expired}; } @{$self->{conditions}};
    my @schars = grep { not $_->{expired}; } @{$self->{conditions}};
    my $lgpCondId4297UPSOutputonInverter_found = 0;
    # irgendwie falscher Alarm. Liebert Spanien meint dazu:
    # Delete the OID "1.3.6.1.4.1.476.1.42.3.2.7.1.4297" from the BMS mapping, which is that of UPS output On Inverter, so that it would no longer bother you in monitoring the equipment.
    # Insert the alternative OID "1.3.6.1.4.476.1.42.3.9.20.1.20.1.2.2.1.4872" which is that of the UPS Output Source, which is a state of the equipment 
    @{$self->{conditions}} = grep {
      if (rindex($_->{lgpConditionDescr}, "lgpCondId4297UPSOutputonInverter ") == 0) {
        $lgpCondId4297UPSOutputonInverter_found = 1;
        0;
      } else {
        1;
      }
    } @{$self->{conditions}};
    if ($lgpCondId4297UPSOutputonInverter_found) {
      $self->{lgpConditionsPresent}--;
    }
  }
  if ($self->implements_mib('LIEBERT-GP-ENVIRONMENTAL-MIB')) {
    $self->get_snmp_tables("LIEBERT-GP-ENVIRONMENTAL-MIB", [
      ["temperatures", "lgpEnvTemperatureDegCTable", "CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::Temperature", sub { my $o = shift; return $o->{valid}}],
      ["humidities", "lgpEnvHumidityRelTable", "CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::Humidity", sub { my $o = shift; return $o->{valid}}],
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
    #$self->mult_snmp_max_msg_size(11);
    # neue Erkenntnis: im Massentest kommt es zu massenhaften Timeouts
    # von 11 auf 15 und schon geht wieder was. Und das ganze Drama,
    # weil sich einer Temperaturen wuenscht. Ein Thermometer haette
    # nicht mal ein Tausendstel von dem gekostet, was ich hierfuer in
    # Rechnung stelle.
    #$self->mult_snmp_max_msg_size(16);
    # Neue Erkenntnis am 12.8.2024: obiges gilt nicht für Griechenland, da
    # kommen sehr häufig Timeouts (60s)
    $self->reset_snmp_max_msg_size();
    $self->mult_snmp_max_msg_size(16);
    $self->get_snmp_tables("LIEBERT-GP-FLEXIBLE-MIB", [
      ["flexentrylabels", "lgpFlexibleExtendedTable", "Monitoring::GLPlugin::SNMP::TableItem"],
      #["flexentrylabels", "lgpFlexibleExtendedTable", "Monitoring::GLPlugin::SNMP::TableItem", undef, ["lgpFlexibleEntryDataDescription"]],
    ]);
    $self->reset_snmp_max_msg_size();
    my @selected_rows = (qw(lgpFlexibleEntryUnitsOfMeasureEnum
        lgpFlexibleEntryDataDescription
        lgpFlexibleEntryIntegerValue
        lgpFlexibleEntryDecimalPosition
        lgpFlexibleEntryUnsignedIntegerValue));
    @selected_rows = ();
    # Unbedingt! Da meint man's gut und schränkt die Rows ein und landet
    # bei 150s pro Flex. Nimmt man da keine Rücksicht und ruft () ab, dann
    # sind's nur noch 2s
    #

    # Kategorien
    # -- Humidity
    # Relative Humidity measured at the humidity sensor		!
    # Over relative humidity warning threshold.			!
    # Over relative humidity alarm threshold.			!
    # Under relative humidity warning threshold.		!
    # Under relative humidity alarm threshold.			!
    # The user assigned relative humidity sensor label		!
    #
    # -- Temperature at the inlet
    # The temperature of the inlet air
    #  ! gibt es doppelt, lgpFlexibleEntryUnitsOfMeasure deg C oder deg F
    # The temperature of the batteries
    #  ! auch zweimal
    # Over temperature warning threshold
    # Under temperature warning threshold
    # Over temperature alarm threshold
    # Under temperature alarm threshold
    #  ! auch doppelt
    if (@{$self->{flexentrylabels}}) {
      my $regex = qr/
          Temperature\ measured\ at\ the\ temperature\ sensor
          | The\ battery\ temperature\ for\ a\ cabinet
          | The\ temperature\ of\ the\ inlet\ air
          | Over\ temperature\ warning\ threshold
          | Over\ temperature\ alarm\ threshold
          | Under\ temperature\ warning\ threshold
          | Under\ temperature\ alarm\ threshold
      /x;
      my @indices = map {
          $_->{indices};
      } grep {
        $_->{lgpFlexibleEntryDataDescription} =~ $regex;
      } @{$self->{flexentrylabels}};
      if (@indices) {
        my $measurement = undef;
        my $warning_from = undef;
        my $warning_to = undef;
        my $critical_from = undef;
        my $critical_to = undef;
        foreach ($self->get_snmp_table_objects("LIEBERT-GP-FLEXIBLE-MIB", "lgpFlexibleExtendedTable", \@indices)) {
          next if (not $_->{lgpFlexibleEntryUnitsOfMeasureEnum} or
              $_->{lgpFlexibleEntryUnitsOfMeasureEnum} ne "degC");
          my $obj = CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexEntry->new(%{$_});
          $measurement = $obj
              if $obj->{lgpFlexibleEntryDataDescription} =~ /(measured|for a cabinet|The temperature of)/;
          bless $measurement, "CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexTemperature"
              if $obj->{lgpFlexibleEntryDataDescription} =~ /(measured|for a cabinet|The temperature of)/;
          $warning_from = $obj->{lgpFlexibleEntryValue}
              if $obj->{lgpFlexibleEntryDataDescription} =~ /Under.*warning/;
          $critical_from = $obj->{lgpFlexibleEntryValue}
              if $obj->{lgpFlexibleEntryDataDescription} =~ /Under.*alarm/;
          $warning_to = $obj->{lgpFlexibleEntryValue}
              if $obj->{lgpFlexibleEntryDataDescription} =~ /Over.*warning/;
          $critical_to = $obj->{lgpFlexibleEntryValue}
              if $obj->{lgpFlexibleEntryDataDescription} =~ /Over.*alarm/;
        }
        if ($measurement) {
          $measurement->{warning_from} = $warning_from if defined $warning_from;
          $measurement->{warning_to} = $warning_to if defined $warning_to;
          $measurement->{critical_from} = $critical_from if defined $critical_from;
          $measurement->{critical_to} = $critical_to if defined $critical_to;
          push(@{$self->{temperatures}}, $measurement)
              if not $measurement->{drecksglump};
        }
      }
      $regex = qr/
          Relative\ Humidity\ measured\ at\ the\ humidity\ sensor
          | Over\ relative\ humidity\ warning\ threshold
          | Over\ relative\ humidity\ alarm\ threshold
          | Under\ relative\ humidity\ warning\ threshold
          | Under\ relative\ humidity\ alarm\ threshold
      /x;
      @indices = map {
          $_->{indices};
      } grep {
        $_->{lgpFlexibleEntryDataDescription} =~ $regex;
      } @{$self->{flexentrylabels}};
      if (@indices) {
        my $measurement = undef;
        my $warning_from = undef;
        my $warning_to = undef;
        my $critical_from = undef;
        my $critical_to = undef;
        foreach ($self->get_snmp_table_objects("LIEBERT-GP-FLEXIBLE-MIB", "lgpFlexibleExtendedTable", \@indices)) {
          my $obj = CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexEntry->new(%{$_});
          $measurement = $obj
              if $obj->{lgpFlexibleEntryDataDescription} =~ /measured/;
          bless $measurement, "CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexHumidity"
              if $obj->{lgpFlexibleEntryDataDescription} =~ /measured/;
          $warning_from = $obj->{lgpFlexibleEntryValue}
              if $obj->{lgpFlexibleEntryDataDescription} =~ /Under.*warning/;
          $critical_from = $obj->{lgpFlexibleEntryValue}
              if $obj->{lgpFlexibleEntryDataDescription} =~ /Under.*alarm/;
          $warning_to = $obj->{lgpFlexibleEntryValue}
              if $obj->{lgpFlexibleEntryDataDescription} =~ /Over.*warning/;
          $critical_to = $obj->{lgpFlexibleEntryValue}
              if $obj->{lgpFlexibleEntryDataDescription} =~ /Over.*alarm/;
        }
        if ($measurement) {
          $measurement->{warning_from} = $warning_from if defined $warning_from;
          $measurement->{warning_to} = $warning_to if defined $warning_to;
          $measurement->{critical_from} = $critical_from if defined $critical_from;
          $measurement->{critical_to} = $critical_to if defined $critical_to;
          push(@{$self->{humidities}}, $measurement)
              if not $measurement->{drecksglump};
        }
      }
      $regex = qr/
          UPS\ output\ source
      /x;
      @indices = map {
          $_->{indices};
      } grep {
        $_->{lgpFlexibleEntryDataDescription} =~ $regex;
      } @{$self->{flexentrylabels}};
      if (@indices) {
        my $measurement = undef;
        foreach ($self->get_snmp_table_objects("LIEBERT-GP-FLEXIBLE-MIB", "lgpFlexibleExtendedTable", \@indices)) {
          $measurement = CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexOutputSource->new(%{$_});
        }
        if ($measurement) {
          push(@{$self->{outputsources}}, $measurement)
              if not $measurement->{drecksglump};
        }
      }
    }
    ##
    # lgpFlexibleEntryDataLabel.1.2.1.4291 = Inlet Air Temperatur
    # "
    # User assigned relative humidity sensor asset tag 01
    # User assigned relative humidity sensor asset tag 02
    # An over relative humidity condition was detected
    # An under relative humidity condition was detected

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
  foreach (@{$self->{humidities}}) {
    $_->check();
  }
  foreach (@{$self->{oknasrsch}}) {
    $_->check();
  }
  foreach (@{$self->{outputsources}}) {
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
  if ($self->{lgpConditionDescr} =~ /^unknown_[\.]*(.*)/) {
    # seufz.... lgpConditionDescr beinhaltet eine oid, welche sowohl aus
    # der eigenen LIEBERT-GP-CONDITIONS-MIB als auch aus der
    # LIEBERT-GP-FLEXIBLE-CONDITIONS-MIB stammen kann. Erstere kann ueber den
    # OID::-Mechanismus aufgeloest werden, Zweitere muss dreckig durchsucht
    # werden.
    $self->require_mib('LIEBERT-GP-FLEXIBLE-CONDITIONS-MIB');
    my $value_which_is_a_oid = $1;
    my @result = grep {
        $Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{'LIEBERT-GP-FLEXIBLE-CONDITIONS-MIB'}->{$_} eq $value_which_is_a_oid
    } keys %{$Monitoring::GLPlugin::SNMP::MibsAndOids::mibs_and_oids->{'LIEBERT-GP-FLEXIBLE-CONDITIONS-MIB'}};
    if (scalar(@result)) {
      $self->{lgpConditionDescr} = $result[0];
    }
    # Das Ding hat sogar noch eine lgpConditionTableRef, die verweist auf
    # variable Tabellen und deren Zeilen und dann kann man sich da Severity
    # und sonstwas holen. Ihr koennt mich aber mal. Ihr kriegt Bescheid,
    # dass eine Condition vorliegt und dann schaut gefaelligst selber nach,
    # was ihr verbockt habt.
    # 10.10.24 ihr kriegt das jetzt doch, weil ihr Conditions nicht einsehen
    # wollt.
    if ($self->{lgpConditionTableRowRef}) {
      $self->{lgpConditionTableRowRef} =~ s/^\.//g;
      my $result = $self->get_request(
          '-varbindlist' => [$self->{lgpConditionTableRowRef}]
      );
      if (defined $result->{$self->{lgpConditionTableRowRef}}) {
        if ($result->{$self->{lgpConditionTableRowRef}} ne "noSuchInstance" and
            $result->{$self->{lgpConditionTableRowRef}} ne "noSuchObject" and
            $result->{$self->{lgpConditionTableRowRef}}) {
          $self->{lgpConditionDescr} .= " (".$result->{$self->{lgpConditionTableRowRef}}.")";
        }
      }
    }
  }
  $self->{expired} = 1;
  $self->{age} = $self->ago_sysuptime($self->{lgpConditionTime});
  if ($self->{age} < 3600*5) {
    # give the service the chance to notify (with a check_interval of 1h)
    # later, ignore these conditions in order not to hide new failures
    # 24.4.24 vorsichtshalber auf Existenz pruefen, da es schon wieder so
    # ein Drecksteil gibt, welches weder lgpConditionCurrentState noch
    # lgpConditionAcknowledged hat. Trotzdem werden lgpConditionOutputToLoadOff
    # und lgpCondId6453InputWiringFault angezeigt. Da ich mehrere UPS mit
    # genau diesen beiden Fehlern sehe, gehe ich davon aus, dass das
    # systematischer Murks ist und es eh wieder heisst:
    # kann man das clientseitig abfangen?
    # Ja, kann man und euer Schrott wird als OK angezeigt, genau so wie ihr
    # es wollt.
    if (exists $self->{lgpConditionCurrentState}) {
      $self->{expired} = 0;
    }
  }
}

sub check {
  my ($self) = @_;
  if (not $self->{expired}) {
    if (exists $self->{lgpConditionCurrentState} and
        $self->{lgpConditionAcknowledged} eq "notAcknowledged" and
        $self->{lgpConditionCurrentState} eq "active") {
      $self->add_info(sprintf "alarm: %s (%d min ago)",
          $self->{lgpConditionDescr}, $self->{age} / 60);
      if ($self->{lgpConditionSeverity} eq "minor") {
        $self->add_warning();
      } elsif ($self->{lgpConditionSeverity} =~ /(major|critical)/) {
        $self->add_critical();
      } elsif ($self->{lgpConditionType} eq "warning") {
        $self->add_warning();
      } elsif ($self->{lgpConditionType} =~ /(alarm|fault)/) {
        $self->add_critical();
        # even if lgpConditionSeverity == not-applicable
      } elsif ($self->{lgpConditionType} eq "message") {
        $self->add_ok();
      }
# was ist damit?
#https://community.se.com/t5/What-s-new-in-EcoStruxure-IT/EcoStruxure-IT-Gateway-device-library-release-notes/ta-p/447033
#Vertiv/Liebert, Various, SNMP
#
#    When lgpConditionType OID returns "alarm" or "fault" and lgpConditionSeverity OID returns "not-applicable", we will report the alarm severity as a critical instead of informational
    }
  }
}

package CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::Humidity;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{valid} = 1;
# TODO
# TODO
# TODO
# TODO
$self->{valid} = 0;
return;
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
    if (! $self->{name}) {
      # und wenne eine Batterietemperatur ist, dann hier. seufz.
      $self->{name} = $self->get_symbol(
          "LIEBERT-GP-POWER-MIB",
          $self->{lgpEnvTemperatureDescrDegC}
      );
    }
  }
  if (! $self->{name}) {
    $self->{name} ||= 'temperature_';
    $self->{name} .= $self->{flat_indices};
  }
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
  if ($self->{name} eq "lgpPwrMeasBattery") {
    # this is only relevant for mode battery-health
    return;
  }
  $self->add_info(sprintf '%s is %.2fC', $self->{name},
      $self->{lgpEnvTemperatureMeasurementDegC}
  );
  $self->set_thresholds(metric => $self->{name});
  # if there are external thresholds, use them
  # --warningx temperature_1=15 --criticalx temperature_1=15
  $self->add_message($self->check_thresholds(
          metric => $self->{name},
          value => $self->{lgpEnvTemperatureMeasurementDegC},
      )
  );
  $self->add_perfdata(
      label => $self->{name},
      value => $self->{lgpEnvTemperatureMeasurementDegC},
  );
}

package CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexEntry;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{drecksglump} = 0;
  if (defined $self->{lgpFlexibleEntryIntegerValue}) {
    $self->{lgpFlexibleEntryValue} = $self->{lgpFlexibleEntryIntegerValue} / 10 ** $self->{lgpFlexibleEntryDecimalPosition};
  } elsif (defined $self->{lgpFlexibleEntryUnsignedIntegerValue}) {
    $self->{lgpFlexibleEntryValue} = $self->{lgpFlexibleEntryUnsignedIntegerValue} / 10 ** $self->{lgpFlexibleEntryDecimalPosition};
  } else {
    # SNMPv2-SMI::enterprises.476.1.42.3.9.30.1.30.1.2.1.4587 = Gauge32: 0
    # SNMPv2-SMI::enterprises.476.1.42.3.9.30.1.40.1.2.1.4587 = INTEGER: 1
    # SNMPv2-SMI::enterprises.476.1.42.3.9.30.1.50.1.2.1.4587 = INTEGER: 1
    # SNMPv2-SMI::enterprises.476.1.42.3.9.30.1.60.1.2.1.4587 = INTEGER: 4124
    # SNMPv2-SMI::enterprises.476.1.42.3.9.30.1.70.1.2.1.4587 = STRING: "Relative Humidity measured at the humidity sensor"
    # War klar, daß irgendwann ein Drecksglump ohne Value auftaucht
    # lgpFlexibleEntryAccessibility: readonly
    # lgpFlexibleEntryDataDescription: Relative Humidity measured at the humidity sensor
    # lgpFlexibleEntryDataType: int16
    # lgpFlexibleEntryDecimalPosition: 0
    # lgpFlexibleEntryUnitsOfMeasureEnum: percent
    $self->{drecksglump} = 1;
  }
}


package CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexTemperature;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  if ($self->{lgpFlexibleEntryIntegerValue} &&
      $self->{lgpFlexibleEntryIntegerValue} ==  2147483647) {
    # Maxint, duerfte ein nicht-existierender Wert sein.
    # Weiss nicht, ob das hier vorkommt, in der obigen MIB schon
#    return;
  }
  $self->{name} = $self->{lgpFlexibleEntryDataDescription};
  if ($self->{name} eq "The battery temperature for a cabinet") {
    $self->{name} = "Cabinet Temperature";
    $self->{label} = "temp_cabinet";
  } elsif ($self->{name} eq "Temperature measured at the temperature sensor") {
    $self->{name} = "Temperature Sensor";
    $self->{label} = "temp_sensor";
  } elsif ($self->{name} =~ /The temperature of the (.*)/) {
    $self->{name} = lc $1;
    $self->{name} =~ s/\s+/_/g;
    $self->{label} = "temp_".$self->{name};
  } else {
    $self->{name} =~ s/Temperature measured at( the)* //g;
    $self->{label} = lc "temp_".$self->{name};
    $self->{label} =~ s/ /_/g;
  }
  my $warning = "";
  my $critical = "";
  if (defined $self->{warning_from}) {
    $warning = $self->{warning_from}.":"
  }
  if (defined $self->{warning_to}) {
    $warning .= $self->{warning_to};
  }
  if (defined $self->{critical_from}) {
    $critical = $self->{critical_from}.":"
  }
  if (defined $self->{critical_to}) {
    $critical .= $self->{critical_to};
  }
  $self->set_thresholds(
      metric => $self->{label},
      warning => $warning,
      critical => $critical,
  );
  $self->add_info(sprintf '%s is %.2fC', $self->{name},
      $self->{lgpFlexibleEntryValue}
  );
  $self->add_message(
      $self->check_thresholds(
          metric => $self->{label},
          value => $self->{lgpFlexibleEntryValue},
      )
  ); # conditions set the status
  $self->add_perfdata(
      label => $self->{label},
      value => $self->{lgpFlexibleEntryValue},
#      warning => $warning,
#      critical => $critical,
  );
}


package CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexHumidity;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  if ($self->{lgpFlexibleEntryIntegerValue} &&
      $self->{lgpFlexibleEntryIntegerValue} ==  2147483647) {
    # Maxint, duerfte ein nicht-existierender Wert sein.
    # Weiss nicht, ob das hier vorkommt, in der obigen MIB schon
#    return;
  }
  $self->{name} = $self->{lgpFlexibleEntryDataDescription};
  $self->{name} =~ s/Relative Humidity measured at( the)* //g;
  $self->{name} =~ s/ /_/g;
  $self->add_info(sprintf '%s is %.2f%%', $self->{name},
      $self->{lgpFlexibleEntryValue}
  );
  $self->add_ok(); # conditions set the status
  my $warning = "";
  my $critical = "";
  if (defined $self->{warning_from}) {
    $warning = $self->{warning_from}.":"
  }
  if (defined $self->{warning_to}) {
    $warning .= $self->{warning_to};
  }
  if (defined $self->{critical_from}) {
    $critical = $self->{critical_from}.":"
  }
  if (defined $self->{critical_to}) {
    $critical .= $self->{critical_to};
  }
  $self->add_perfdata(
      label => $self->{name},
      value => $self->{lgpFlexibleEntryValue},
      uom => "%",
      warning => $warning,
      critical => $critical,
  );
}

package CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexOutputSource;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{lgpFlexibleEntryValue} = {
      1 => "Other",
      2 => "Off",
      3 => "Normal",
      4 => "Bypass",
      5 => "Battery",
      6 => "Booster",
      7 => "Reduce",
  }->{$self->{lgpFlexibleEntryUnsignedIntegerValue}};
}

sub check {
  my ($self) = @_;
  $self->add_info(sprintf "UPS output source is %s", $self->{lgpFlexibleEntryValue});
  if ($self->{lgpFlexibleEntryValue} eq "Normal") {
    $self->add_ok();
  } else {
    $self->add_critical();
  }
}


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
    #$self->mult_snmp_max_msg_size(11);
    # neue Erkenntnis: im Massentest kommt es zu massenhaften Timeouts
    # von 11 auf 15 und schon geht wieder was. Und das ganze Drama,
    # weil sich einer Temperaturen wuenscht. Ein Thermometer haette
    # nicht mal ein Tausendstel von dem gekostet, was ich hierfuer in
    # Rechnung stelle.
    $self->mult_snmp_max_msg_size(16);
    $self->get_snmp_tables("LIEBERT-GP-FLEXIBLE-MIB", [
      ["flexentrylabels", "lgpFlexibleExtendedTable", "Monitoring::GLPlugin::SNMP::TableItem", sub {my $o = shift; $o->{lgpFlexibleEntryDataDescription} =~ /battery.*temperature/i;}, ["lgpFlexibleEntryDataDescription"]],
    ]);
    if (@{$self->{flexentrylabels}}) {
      my @indices = map {
          $_->{indices};
      } @{$self->{flexentrylabels}};
      if (@indices) {
        foreach ($self->get_snmp_table_objects("LIEBERT-GP-FLEXIBLE-MIB", "lgpFlexibleExtendedTable", \@indices)) {
          my $flexlabel = CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem::FlexTemperature->new(%{$_});
          push(@{$self->{flexlabels}}, $flexlabel) if
              $flexlabel->{valid} and
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
  $self->{valid} = 1;
  if (! defined $self->{lgpFlexibleEntryIntegerValue}) {
    $self->{valid} = 0;
    return;
  }
  $self->{lgpFlexibleEntryValue} = $self->{lgpFlexibleEntryIntegerValue} / 10 ** $self->{lgpFlexibleEntryDecimalPosition};
  # lgpFlexibleEntryDataDescription: The battery temperature for a cabinet
  # kein Ahnung, ob da noch weitere dazukommen koennen
  # gehen wir mal zunaechst davon aus, dass es nur eine Batterie gibt.
  $self->{name} ||= 'Battery temperature';
  #$self->{name} ||= 'battery_temp_';
  #$self->{name} .= $self->{flat_indices};
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


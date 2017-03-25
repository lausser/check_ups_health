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
  if ($self->{lgpConditionsPresent}) {
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
  foreach (@{$self->{temperatures}}) {
    $_->check();
  }
}


package Classes::Liebert::Components::EnvironmentalSubsystem::Condition;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
}

package Classes::Liebert::Components::EnvironmentalSubsystem::Temperature;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  if ($self->{lgpEnvTemperatureDescrDegC} =~ /^[\.\d]+$/) {
    my $result = $self->get_request(
        '-varbindlist' => [$self->{lgpEnvTemperatureDescrDegC}]
    );
    # vielleicht irgendwann mal. gegen einwurf von muenzen
    #printf %s\n", Data::Dumper::Dumper($result);
  }
  if ($self->{lgpEnvTemperatureDescrDegC} =~ /^[\.\d]+$/) {
    $self->{name} = $self->{lgpEnvTemperatureIdDegC}
  }
}

sub check {
  my ($self) = @_;
  $self->add_info(sprintf 'temperature %s is %.2fC', $self->{name},
      $self->{lgpEnvTemperatureMeasurementDegC}
  );
  $self->add_ok();
  $self->add_perfdata(
      label => 'temperature_'.$self->{name},
      value => $self->{lgpEnvTemperatureMeasurementDegC},
  );
}


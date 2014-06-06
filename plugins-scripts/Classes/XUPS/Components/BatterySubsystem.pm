package Classes::XUPS::Components::BatterySubsystem;
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
  $self->get_snmp_objects("XUPS-MIB", qw(xupsBatTimeRemaining xupsBatVoltage xupsBatCurrent xupsBatCapacity xupsInputFrequency xupsOutputFrequency xupsOutputLoad xupsTestBatteryStatus));
  $self->get_snmp_tables("XUPS-MIB", [
      ["inputs", "xupsInputTable", "Classes::XUPS::Components::BatterySubsystem::Input"],
      ["outputs", "xupsOutputTable", "Classes::XUPS::Components::BatterySubsystem::Output"],
  ]);
  $self->{xupsBatTimeRemaining} /= 60;
  $self->{xupsInputFrequency} /= 10;
  $self->{xupsOutputFrequency} /= 10;
}

sub check {
  my $self = shift;
  $self->add_info('checking battery');
  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  $self->add_info(sprintf 'capacity is %.2f%%', $self->{xupsBatCapacity});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{xupsBatCapacity},
          metric => 'capacity'));
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{xupsBatCapacity},
      uom => '%',
  );

  $self->set_thresholds(
      metric => 'output_load', warning => '75', critical => '85');
  $self->add_info(sprintf 'output load %.2f%%', $self->{xupsOutputLoad});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{xupsOutputLoad},
          metric => 'output_load'));
  $self->add_perfdata(
      label => 'output_load',
      value => $self->{xupsOutputLoad},
      uom => '%',
  );
  $self->add_perfdata(
      label => 'output_frequency',
      value => $self->{xupsOutputFrequency});
  foreach (@{$self->{outputs}}) {
    $_->check();
  }
  $self->add_perfdata(
      label => 'input_frequency',
      value => $self->{xupsInputFrequency});
  foreach (@{$self->{inputs}}) {
    $_->check();
  }

  $self->set_thresholds(
      metric => 'remaining_time', warning => '15:', critical => '10:');
  $self->add_info(sprintf 'remaining battery run time is %.2fmin', $self->{xupsBatTimeRemaining});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{xupsBatTimeRemaining},
          metric => 'remaining_time'));
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{xupsBatTimeRemaining},
  );

  if ($self->{xupsTestBatteryStatus} eq "failed") {
    $self->add_critical("battery has status: failed");
  }
}

sub dump {
  my $self = shift;
  printf "[BATTERY]\n";
  foreach (grep /^xups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


package Classes::XUPS::Components::BatterySubsystem::Input;
our @ISA = qw(GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my $self = shift;
  if ($self->{xupsInputVoltage} < 1) {
    $self->add_critical(sprintf 'input power%s outage', $self->{flat_indices});
  }
  $self->add_perfdata(
      label => 'input_voltage'.$self->{flat_indices},
      value => $self->{xupsInputVoltage},
  );
  $self->add_perfdata(
      label => 'input_current'.$self->{flat_indices},
      value => $self->{xupsInputCurrent} || 0,
  );
}

package Classes::XUPS::Components::BatterySubsystem::Output;
our @ISA = qw(GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my $self = shift;
  $self->add_perfdata(
      label => 'output_voltage_'.$self->{flat_indices},
      value => $self->{xupsOutputVoltage},
  );
  $self->add_perfdata(
      label => 'output_current'.$self->{flat_indices},
      value => $self->{xupsOutputCurrent},
  );
}

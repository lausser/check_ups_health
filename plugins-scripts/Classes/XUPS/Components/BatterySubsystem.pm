package Classes::XUPS::Components::BatterySubsystem;
our @ISA = qw(Classes::XUPS);
use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my $self = shift;
  $self->get_snmp_objects("XUPS-MIB", qw(xupsBatTimeRemaining xupsBatVoltage xupsBatCurrent xupsBatCapacity xupsInputFrequency xupsOutputFrequency xupsOutputLoad));
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
  my $info = sprintf 'capacity is %.2f%%', $self->{xupsBatCapacity};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{xupsBatCapacity},
          metric => 'capacity'), $info);
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{xupsBatCapacity},
      uom => '%',
      warning => ($self->get_thresholds(metric => 'capacity'))[0],
      critical => ($self->get_thresholds(metric => 'capacity'))[1],
  );

  $self->set_thresholds(
      metric => 'output_load', warning => '75', critical => '85');
  $info = sprintf 'output load %.2f%%', $self->{xupsOutputLoad};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{xupsOutputLoad},
          metric => 'output_load'), $info);
  $self->add_perfdata(
      label => 'output_load',
      value => $self->{xupsOutputLoad},
      uom => '%',
      warning => ($self->get_thresholds(metric => 'output_load'))[0],
      critical => ($self->get_thresholds(metric => 'output_load'))[1],
  );
  $self->add_perfdata(
      label => 'output_frequency',
      value => $self->{xupsOutputFrequency});
  foreach (@{$self->{outputs}}) {
    $self->add_perfdata(
        label => 'output_voltage_'.$_->{flat_indices},
        value => $_->{xupsOutputVoltage},
    );
  }
  $self->add_perfdata(
      label => 'input_frequency',
      value => $self->{xupsInputFrequency});
  foreach (@{$self->{inputs}}) {
    $self->add_perfdata(
        label => 'input_voltage_'.$_->{flat_indices},
        value => $_->{xupsInputVoltage},
    );
  }

  $self->set_thresholds(
      metric => 'remaining_time', warning => '15:', critical => '10:');
  $info = sprintf 'remaining battery run time is %.2fmin', $self->{xupsBatTimeRemaining};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{xupsBatTimeRemaining},
          metric => 'remaining_time'), $info);
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{xupsBatTimeRemaining},
      warning => ($self->get_thresholds(metric => 'remaining_time'))[0],
      critical => ($self->get_thresholds(metric => 'remaining_time'))[1],
  );
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
our @ISA = qw(GLPlugin::TableItem);

package Classes::XUPS::Components::BatterySubsystem::Output;
our @ISA = qw(GLPlugin::TableItem);


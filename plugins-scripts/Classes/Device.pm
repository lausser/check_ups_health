package Classes::Device;
our @ISA = qw(Monitoring::GLPlugin::SNMP);
use strict;

sub classify {
  my ($self) = @_;
  if (! ($self->opts->hostname || $self->opts->snmpwalk)) {
    $self->add_unknown('either specify a hostname or a snmpwalk file');
  } else {
    $self->check_snmp_and_model();
    if (! $self->check_messages()) {
      if ($self->opts->verbose && $self->opts->verbose) {
        printf "I am a %s\n", $self->{productname};
      }
      $self->map_oid_to_class('1.3.6.1.4.1.4555.1.1.1', 'Classes::Socomec::Netvision');
      $self->map_oid_to_class('1.3.6.1.4.1.318.1.3.17.1', 'Classes::APC::Powermib');
      if ($self->opts->mode =~ /^my-/) {
        $self->load_my_extension();
      } elsif ($self->get_snmp_object('PowerNet-MIB', 'upsBasicIdentModel') ||
          $self->get_snmp_object('PowerNet-MIB', 'upsBasicIdentName')) {
        # upsBasicIdentModel kann auch "" sein, upsBasicIdentName
        # theoretisch auch (da r/w), aber hoffentlich nicht beide zusammen
        bless $self, 'Classes::APC::Powermib::UPS';
        $self->debug('using Classes::APC::Powermib::UPS');
      } elsif ($self->{productname} =~ /APC /) {
        bless $self, 'Classes::APC';
        $self->debug('using Classes::APC');
      } elsif ($self->implements_mib('MG-SNMP-UPS-MIB')) {
        # like XPPC, that's why UPS is now last
        bless $self, 'Classes::MerlinGerin';
        $self->debug('using Classes::MerlinGerin');
      } elsif ($self->implements_mib('LIEBERT-GP-POWER-MIB')) {
        bless $self, 'Classes::Liebert';
        $self->debug('using Classes::Liebert');
      } elsif ($self->implements_mib('ATS-THREEPHASE-MIB')) {
        $self->rebless('Classes::ATS');
      } elsif ($self->implements_mib('UPSV4-MIB')) {
        bless $self, 'Classes::V4';
        $self->debug('using Classes::V4');
      } elsif ($self->implements_mib('XPPC-MIB')) {
        # before UPS-MIB because i found a Intelligent MSII6000 which implemented
        # both XPPC and UPS, but the latter only partial
        bless $self, 'Classes::XPPC';
        $self->debug('using Classes::XPPC');
      } elsif ($self->implements_mib('XUPS-MIB')) {
        bless $self, 'Classes::XUPS';
        $self->debug('using Classes::XUPS');
      } elsif ($self->{productname} =~ /Net Vision v6/) {
        bless $self, 'Classes::Socomec';
        $self->debug('using Classes::Socomec');
      } elsif ($self->implements_mib('UPS-MIB')) {
        bless $self, 'Classes::UPS';
        $self->debug('using Classes::UPS');
      } else {
        $self->map_oid_to_class('1.3.6.1.4.1.318.1.3.17.1',
            'Classes::APC::Powermib');
        $self->map_oid_to_class('1.3.6.1.4.1.4555.1.1.1',
            'Classes::Socomec::Netvision');
        if (my $class = $self->discover_suitable_class()) {
          bless $self, $class;
          $self->debug('using '.$class);
        } else {
          bless $self, 'Classes::Generic';
          $self->debug('using Classes::Generic');
        }
      }
    }
  }
  return $self;
}

sub check_snmp_and_model {
  my ($self) = @_;
  $self->SUPER::check_snmp_and_model();
  if ($self->check_messages() == 3 && ($self->check_messages())[1] =~ /neither sysUptime/) {
    # firmwareupdate und dann sowas:
    # .1.3.6.1.2.1.33.1.1.2.0 = STRING: "TRIMOD"
    # .1.3.6.1.2.1.33.1.1.3.0 = STRING: "3.10.1"
    # .1.3.6.1.2.1.33.1.1.4.0 = STRING: "cs141 v "
    # .1.3.6.1.2.1.33.1.1.5.0 = STRING: "CS141 SNMP/WEB Adapter"
    # kein 1.3.6.1.2.1, nix mehr, gaaar nix
    $self->establish_snmp_session();
    if ($self->implements_mib('UPS-MIB') &&
        $self->get_snmp_object('UPS-MIB', 'upsIdentModel') =~ /TRIMOD/) {
      $self->clear_messages(3);
      bless $self, 'Classes::UPS';
      $self->debug('using Classes::UPS');
      $self->debug("check for UPSMIB");
      $self->{uptime} = 3600;
      $self->{productname} = "TRIMOD-with-broken-firmware";
      $self->{sysobjectid} = "1.3.6.1.2.1.33";
    }
  }
}


package Classes::Generic;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /.*/) {
    bless $self, 'Monitoring::GLPlugin::SNMP';
    $self->no_such_mode();
  }
}


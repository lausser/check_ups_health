package UPS::Device;
our @ISA = qw(GLPlugin::SNMP);

use strict;
use IO::File;
use File::Basename;
use Digest::MD5  qw(md5_hex);
use Errno;
use AutoLoader;
our $AUTOLOAD;

use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

{
  our $mode = undef;
  our $plugin = undef;
  our $blacklist = undef;
  our $session = undef;
  our $rawdata = {};
  our $info = [];
  our $extendedinfo = [];
  our $summary = [];
  our $statefilesdir = '/var/tmp/check_ups_health';
  our $oidtrace = [];
  our $uptime = 0;
}

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    productname => 'unknown',
  };
  bless $self, $class;
  if (! ($self->opts->hostname || $self->opts->snmpwalk)) {
    $self->add_message(UNKNOWN, 'either specify a hostname or a snmpwalk file');
  } else {
    $self->check_snmp_and_model();
    if (! $self->check_messages()) {
      if ($self->opts->verbose && $self->opts->verbose) {
        printf "I am a %s\n", $self->{productname};
      }
      if ($self->get_snmp_object('PowerNet-MIB', 'upsBasicIdentModel')) {
        bless $self, 'UPS::APC::Powermib';
        $self->debug('using UPS::APC::Powermib');
      } elsif ($self->{productname} =~ /APC /) {
        bless $self, 'UPS::APC';
        $self->debug('using UPS::APC');
      } elsif ($self->implements_mib('UPSV4-MIB')) {
        bless $self, 'UPS::V4';
        $self->debug('using UPS::V4');
      } else {
        if (my $class = $self->discover_suitable_class()) {
          bless $self, $class;
          $self->debug('using '.$class);
        } elsif ($self->mode =~ /device::uptime/) {
          bless $self, 'GLPlugin::SNMP';
        } else {
          $self->add_message(UNKNOWN, 'the device did not implement the mibs this plugin is asking for');
          $self->add_message(UNKNOWN,
              sprintf('unknown device%s', $self->{productname} eq 'unknown' ?
                  '' : '('.$self->{productname}.')'));
        }
      }
    }
  }
  return $self;
}


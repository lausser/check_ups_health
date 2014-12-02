#! /usr/bin/perl

use strict;
use File::Basename;

my $plugin = Classes::Device->new(
    shortname => '',
    usage => 'Usage: %s [ -v|--verbose ] [ -t <timeout> ] '.
        '--mode <what-to-do> '.
        '--hostname <network-component> --community <snmp-community>'.
        '  ...]',
    version => '$Revision: #PACKAGE_VERSION# $',
    blurb => 'This plugin checks various parameters of network components ',
    url => 'http://labs.consol.de/nagios/check_ups_health',
    timeout => 60,
    plugin => basename($0),
);

$plugin->add_mode(
    internal => 'device::uptime',
    spec => 'uptime',
    alias => undef,
    help => 'Check the uptime of the device',
);
$plugin->add_mode(
    internal => 'device::hardware::health',
    spec => 'hardware-health',
    alias => undef,
    help => 'Check the status of environmental equipment (fans, temperatures, power, selftests)',
);
$plugin->add_mode(
    internal => 'device::battery::health',
    spec => 'battery-health',
    alias => ['power-health'],
    help => 'Check the status of battery equipment (batteries, currencies)',
);
$plugin->add_mode(
    internal => 'device::supportedmibs',
    spec => 'supportedmibs',
    alias => undef,
    help => 'Shows the names of the mibs which this devices has implemented (only lausser may run this command)',
);
$plugin->add_arg(
    spec => 'blacklist|b=s',
    help => '--blacklist
   Blacklist some (missing/failed) components',
    required => 0,
    default => '',
);
$plugin->add_arg(
    spec => 'hostname|H=s',
    help => '--hostname
   Hostname or IP-address of the ups',
    required => 0,
);
$plugin->add_snmp_args();
$plugin->add_arg(
    spec => 'mode=s',
    help => "--mode
   A keyword which tells the plugin what to do",
    required => 1,
);
$plugin->add_arg(
    spec => 'name=s',
    help => "--name
   The name of an interface (ifDescr)",
    required => 0,
);
$plugin->add_arg(
    spec => 'drecksptkdb=s',
    help => "--drecksptkdb
   This parameter must be used instead of --name, because Devel::ptkdb is stealing the latter from the command line",
    aliasfor => "name",
    required => 0,
);
$plugin->add_arg(
    spec => 'regexp',
    help => "--regexp
   A flag indicating that --name is a regular expression",
    required => 0,
);
$plugin->add_arg(
    spec => 'units=s',
    help => "--units
   One of %, B, KB, MB, GB, Bit, KBi, MBi, GBi. (used for e.g. mode interface-usage)",
    required => 0,
);
$plugin->add_arg(
    spec => 'report=s',
    help => "--report
   Can be used to shorten the output",
    required => 0,
    default => 'long',
);
$plugin->add_arg(
    spec => 'lookback=s',
    help => "--lookback
   The amount of time you want to look back when calculating average rates.
   Use it for mode interface-errors or interface-usage. Without --lookback
   the time between two runs of check_nwc_health is the base for calculations.
   If you want your checkresult to be based for example on the past hour,
   use --lookback 3600. ",
    required => 0,
);
$plugin->add_arg(
    spec => 'critical=s',
    help => '--critical
   The critical threshold',
    required => 0,
);
$plugin->add_arg(
    spec => 'warning=s',
    help => '--warning
   The warning threshold',
    required => 0,
);
$plugin->add_arg(
    spec => 'warningx=s%',
    help => '--warningx
   The extended warning thresholds',
    required => 0,
);
$plugin->add_arg(
    spec => 'criticalx=s%',
    help => '--criticalx
   The extended critical thresholds',
    required => 0,
);
$plugin->add_arg(
    spec => 'mitigation=s',
    help => "--mitigation
   The parameter allows you to change a critical error to a warning.",
    required => 0,
);
$plugin->add_arg(
    spec => 'selectedperfdata=s',
    help => "--selectedperfdata
   The parameter allows you to limit the list of performance data. It's a perl regexp.
   Only matching perfdata show up in the output",
    required => 0,
);
$plugin->add_arg(
    spec => 'negate=s%',
    help => "--negate
   The parameter allows you to map exit levels, such as warning=critical",
    required => 0,
);
$plugin->add_arg(
    spec => 'with-mymodules-dyn-dir=s',
    help => '--with-mymodules-dyn-dir
   A directory where own extensions can be found',
    required => 0,
);
$plugin->add_arg(
    spec => 'servertype=s',
    help => '--servertype
   The type of the network device: cisco (default). Use it if auto-detection
   is not possible',
    required => 0,
);
$plugin->add_arg(
    spec => 'statefilesdir=s',
    help => '--statefilesdir
   An alternate directory where the plugin can save files',
    required => 0,
);
$plugin->add_arg(
    spec => 'snmpwalk=s',
    help => '--snmpwalk
   A file with the output of a snmpwalk (used for simulation)
   Use it instead of --hostname',
    required => 0,
);
$plugin->add_arg(
    spec => 'oids=s',
    help => '--oids
   A list of oids which are downloaded and written to a cache file.
   Use it together with --mode oidcache',
    required => 0,
);
$plugin->add_arg(
    spec => 'offline:i',
    help => '--offline
   The maximum number of seconds since the last update of cache file before
   it is considered too old',
    required => 0,
);
$plugin->add_arg(
    spec => 'multiline',
    help => '--multiline
   Multiline output',
    required => 0,
);

$plugin->getopts();
$plugin->classify();
$plugin->validate_args();

if (! $plugin->check_messages()) {
  $plugin->init();
  if (! $plugin->check_messages()) {
    $plugin->add_ok($plugin->get_summary())
        if $plugin->get_summary();
    $plugin->add_ok($plugin->get_extendedinfo(" "))
        if $plugin->get_extendedinfo();
  }
}
my ($code, $message) = $plugin->opts->multiline ?
    $plugin->check_messages(join => "\n", join_all => ', ') :
    $plugin->check_messages(join => ', ', join_all => ', ');
$message .= sprintf "\n%s\n", $plugin->get_info("\n")
    if $plugin->opts->verbose >= 1;
#printf "%s\n", Data::Dumper::Dumper($plugin);
$plugin->nagios_exit($code, $message);


## Process this file with automake to produce Makefile.in

SED=/bin/sed
GREP=/bin/grep
CAT=/bin/cat
ECHO=/bin/echo

SUFFIXES = .pl .pm .sh

VPATH=$(top_srcdir) $(top_srcdir)/plugins-scripts $(top_srcdir)/plugins-scripts/t

libexec_SCRIPTS=check_ups_health
MY_MODULES=
EXTRA_MODULES=\
  Nagios/MiniPlugin.pm \
  GLPlugin.pm \
  Classes/MibsAndOids.pm \
  Classes/APC/Powermib/Components/EnvironmentalSubsystem.pm \
  Classes/APC/Powermib/Components/BatterySubsystem.pm \
  Classes/APC/Powermib.pm \
  Classes/APC.pm \
  Classes/Socomec/Netvision/Components/EnvironmentalSubsystem.pm \
  Classes/Socomec/Netvision/Components/BatterySubsystem.pm \
  Classes/Socomec/Netvision.pm \
  Classes/Socomec.pm \
  Classes/XUPS/Components/EnvironmentalSubsystem.pm \
  Classes/XUPS/Components/BatterySubsystem.pm \
  Classes/XUPS.pm \
  Classes/V4/Components/EnvironmentalSubsystem.pm \
  Classes/V4/Components/BatterySubsystem.pm \
  Classes/V4.pm \
  Classes/MerlinGerin/Components/EnvironmentalSubsystem.pm \
  Classes/MerlinGerin/Components/BatterySubsystem.pm \
  Classes/MerlinGerin.pm \
  Classes/Device.pm
EXTRA_DIST=check_ups_health.pl $(EXTRA_MODULES)

CLEANFILES=$(libexec_SCRIPTS)

AM_INSTALL_PROGRAM_FLAGS=@INSTALL_OPTS@

.pm :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

.pl :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

.sh :
	(AWK) -f ./subst $< > $@
	chmod +x $@

$(libexec_SCRIPTS) : $(EXTRA_DIST)
	$(ECHO) "#! #PERL# -w" | $(AWK) -f ./subst > $@
	$(ECHO) >> $@
	for m in ${EXTRA_MODULES}; do \
		$(SED) -e 's/^1;//g' < $$m | $(AWK) -f ./subst | $(GREP) -v "use Nagios::Plugin" >> $@; \
	done
	$(ECHO) "package main;" >> $@
	$(CAT) check_ups_health.pl | $(AWK) -f ./subst >> $@
	chmod +x $@
#| $(GREP) -v "use Nagios" >> $@;


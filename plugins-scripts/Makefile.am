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
  UPS/MibsAndOids.pm \
  UPS/APC/Powermib/Components/EnvironmentalSubsystem.pm \
  UPS/APC/Powermib/Components/BatterySubsystem.pm \
  UPS/APC/Powermib.pm \
  UPS/APC.pm \
  UPS/Socomec/Netvision/Components/EnvironmentalSubsystem.pm \
  UPS/Socomec/Netvision/Components/BatterySubsystem.pm \
  UPS/Socomec/Netvision.pm \
  UPS/Socomec.pm \
  UPS/XUPS/Components/EnvironmentalSubsystem.pm \
  UPS/XUPS/Components/BatterySubsystem.pm \
  UPS/XUPS.pm \
  UPS/V4/Components/EnvironmentalSubsystem.pm \
  UPS/V4/Components/BatterySubsystem.pm \
  UPS/V4.pm \
  UPS/Device.pm
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


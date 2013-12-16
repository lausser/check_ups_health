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
  UPS/APC/MGE/Components/BatterySubsystem.pm \
  UPS/APC/MGE.pm \
  UPS/APC.pm \
  UPS/V4/Components/EnvironmentalSubsystem.pm \
  UPS/V4/Components/BatterySubsystem.pm \
  UPS/V4.pm \
  UPS/IFMIB/Component/LinkAggregation.pm \
  UPS/IFMIB/Component/InterfaceSubsystem.pm \
  UPS/IFMIB.pm \
  UPS/MibsAndOids.pm \
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


libexec_SCRIPTS=check_ups_health
GL_MODULES=\
  ../lib/Monitoring/GLPlugin/Commandline/Getopt.pm \
  ../lib/Monitoring/GLPlugin/Commandline.pm \
  ../lib/Monitoring/GLPlugin.pm \
  ../lib/Monitoring/GLPlugin/Item.pm \
  ../lib/Monitoring/GLPlugin/TableItem.pm \
  ../lib/Monitoring/GLPlugin/SNMP.pm \
  ../lib/Monitoring/GLPlugin/SNMP/MibsAndOids.pm \
  ../lib/Monitoring/GLPlugin/SNMP/MibsAndOids/MIB2MIB.pm \
  ../lib/Monitoring/GLPlugin/SNMP/MibsAndOids/SNMPFRAMEWORKMIB.pm \
  ../lib/Monitoring/GLPlugin/SNMP/MibsAndOids/POWERNETMIB.pm \
  ../lib/Monitoring/GLPlugin/SNMP/CSF.pm \
  ../lib/Monitoring/GLPlugin/SNMP/Item.pm \
  ../lib/Monitoring/GLPlugin/SNMP/TableItem.pm
EXTRA_MODULES=\
  Classes/APC/Powermib/UPS/Components/EnvironmentalSubsystem.pm \
  Classes/APC/Powermib/UPS/Components/BatterySubsystem.pm \
  Classes/APC/Powermib/UPS.pm \
  Classes/APC/Powermib/ATS/Components/EnvironmentalSubsystem.pm \
  Classes/APC/Powermib/ATS/Components/BatterySubsystem.pm \
  Classes/APC/Powermib/ATS.pm \
  Classes/APC/Powermib.pm \
  Classes/APC.pm \
  Classes/Socomec/Netvision/Components/EnvironmentalSubsystem.pm \
  Classes/Socomec/Netvision/Components/BatterySubsystem.pm \
  Classes/Socomec/Netvision.pm \
  Classes/Socomec.pm \
  Classes/UPS/Components/EnvironmentalSubsystem.pm \
  Classes/UPS/Components/BatterySubsystem.pm \
  Classes/UPS.pm \
  Classes/XUPS/Components/EnvironmentalSubsystem.pm \
  Classes/XUPS/Components/BatterySubsystem.pm \
  Classes/XUPS.pm \
  Classes/XPPC/Components/EnvironmentalSubsystem.pm \
  Classes/XPPC/Components/BatterySubsystem.pm \
  Classes/XPPC.pm \
  Classes/V4/Components/EnvironmentalSubsystem.pm \
  Classes/V4/Components/BatterySubsystem.pm \
  Classes/V4.pm \
  Classes/MerlinGerin/Components/EnvironmentalSubsystem.pm \
  Classes/MerlinGerin/Components/BatterySubsystem.pm \
  Classes/MerlinGerin.pm \
  Classes/Device.pm

SED=/bin/sed
GREP=/bin/grep
CAT=/bin/cat
ECHO=/bin/echo
if DISABLE_STANDALONE
STANDALONE = no
else
STANDALONE = yes
endif

SUFFIXES = .pl .pm .sh

VPATH=$(top_srcdir) $(top_srcdir)/plugins-scripts $(top_srcdir)/plugins-scripts/t

EXTRA_DIST=$(libexec_SCRIPTS).pl $(EXTRA_MODULES) $(GL_MODULES)

CLEANFILES=$(libexec_SCRIPTS)

AM_INSTALL_PROGRAM_FLAGS=@INSTALL_OPTS@

.pm :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

.pl :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

.sh :
	$(AWK) -f ./subst $< > $@
	chmod +x $@

$(libexec_SCRIPTS) : $(EXTRA_DIST)
	if [ -f ../../GLPlugin/lib/Monitoring/GLPlugin.pm ]; then cp -r ../../GLPlugin/lib ..; fi
	$(ECHO) "#! #PERL# -w" | $(AWK) -f ./subst > $@
	$(ECHO) "# nagios: -epn" >> $@
	$(ECHO) >> $@
	if [ "${STANDALONE}" == "yes" ]; then \
		$(ECHO) i am standalone; \
		for m in ${GL_MODULES}; do \
			$(SED) -e 's/^1;//g' < $$m | $(SED) -e '/^__END__/,$$d' | $(AWK) -f ./subst >> $@; \
		done \
	fi
	for m in ${EXTRA_MODULES}; do \
		$(SED) -e 's/^1;//g' < $$m | $(SED) -e '/^__END__/,$$d' | $(AWK) -f ./subst >> $@; \
	done
	$(ECHO) "package main;" >> $@
	$(CAT) $(libexec_SCRIPTS).pl | $(AWK) -f ./subst >> $@
	chmod +x $@


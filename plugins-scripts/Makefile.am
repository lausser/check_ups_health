libexec_SCRIPTS=check_ups_health
GL_MODULES=\
  ../GLPlugin/lib/Monitoring/GLPlugin/Commandline/Extraopts.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/Commandline/Getopt.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/Commandline.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/Item.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/TableItem.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/CSF.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/Item.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/TableItem.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/SysDescPrettify.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/LIEBERTGPAGENTMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/LIEBERTGPCONDITIONSMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/LIEBERTGPENVIRONMENTALMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/LIEBERTGPFLEXIBLEMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/LIEBERTGPPOWERMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/LIEBERTGPREGISTRATIONMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/LIEBERTGPSYSTEMMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/MGSNMPUPSMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/MIB2MIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/NETVISIONV6MIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/POWERNETMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/SNMPFRAMEWORKMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/UPSMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/UPSV4MIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/XPPCMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/XUPSMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/UPSMANRIELLOSENTRMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/ATSMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/ATSTHREEPHASEMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/EPPCMIB.pm \
  ../GLPlugin/lib/Monitoring/GLPlugin/SNMP/MibsAndOids/HOSTRESOURCESMIB.pm
EXTRA_MODULES=\
  Classes/APC/Powermib/UPS/Component/EnvironmentalSubsystem.pm \
  Classes/APC/Powermib/UPS/Component/BatterySubsystem.pm \
  Classes/APC/Powermib/UPS.pm \
  Classes/APC/Powermib.pm \
  Classes/APC.pm \
  Classes/Socomec/Netvision/Component/EnvironmentalSubsystem.pm \
  Classes/Socomec/Netvision/Component/BatterySubsystem.pm \
  Classes/Socomec/Netvision.pm \
  Classes/Socomec.pm \
  Classes/UPS/Component/EnvironmentalSubsystem.pm \
  Classes/UPS/Component/BatterySubsystem.pm \
  Classes/UPS.pm \
  Classes/XUPS/Component/AlarmSubsystem.pm \
  Classes/XUPS/Component/TempHumSubsystem.pm \
  Classes/XUPS/Component/EnvironmentalSubsystem.pm \
  Classes/XUPS/Component/BatterySubsystem.pm \
  Classes/XUPS.pm \
  Classes/EPPC/Component/EnvironmentalSubsystem.pm \
  Classes/EPPC/Component/BatterySubsystem.pm \
  Classes/EPPC.pm \
  Classes/XPPC/Component/EnvironmentalSubsystem.pm \
  Classes/XPPC/Component/BatterySubsystem.pm \
  Classes/XPPC.pm \
  Classes/V4/Component/EnvironmentalSubsystem.pm \
  Classes/V4/Component/BatterySubsystem.pm \
  Classes/V4.pm \
  Classes/MerlinGerin/Component/EnvironmentalSubsystem.pm \
  Classes/MerlinGerin/Component/BatterySubsystem.pm \
  Classes/MerlinGerin.pm \
  Classes/Liebert/Component/EnvironmentalSubsystem.pm \
  Classes/Liebert/Component/BatterySubsystem.pm \
  Classes/Liebert.pm \
  Classes/ATS/ATSTHREEPHASE/Component/EnvironmentalSubsystem.pm \
  Classes/ATS/ATSTHREEPHASE/Component/BatterySubsystem.pm \
  Classes/ATS.pm \
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


PLUGIN=check_ups_health

docs: dedoc
	$(RM) $(PLUGIN).html
	cat $(PLUGIN).de.html >> $(PLUGIN).html
	sed -ri '/col width/d' $(PLUGIN).html
	sed -ri 's/$$/\r/' $(PLUGIN).html

dedoc:
	asciidoc --unsafe --no-header-footer -a max-width=800 $(PLUGIN).de.txt

endoc:
	asciidoc --unsafe --no-header-footer -a max-width=800 $(PLUGIN).en.txt

clean:
	rm $(PLUGIN).de.html

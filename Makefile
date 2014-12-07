
#-------------------------------------------------------------------------------

# These are used internally by debuild.  "build" should be first.

build:

clean:

install:
	# if using debuild, then $(DESTDIR) makefile variable will be set
	install -D -o root -g root -m 0755 src/flashback $(DESTDIR)/usr/sbin/flashback
	for f in $(cd examples ; ls -1) ; do \
		install -D -o root -g root -m 0644 examples/$$f $(DESTDIR)/usr/share/doc/flashback/examples/$$f ; \
	done
	# for non-debuild installations, install the init.d script, too
	if [ -z "$(DESTDIR)" ] ; then \
		install -D -o root -g root -m 0755 startup/init.d/flashback /etc/init.d/flashback ; \
	fi

uninstall:
	-rm -f $(DESTDIR)/usr/sbin/flashback
	-rm -rf $(DESTDIR)/usr/share/doc/flashback
	-rm -f $(DESTDIR)/etc/init.d/flashback
	-rm -f $(DESTDIR)/var/lib/flashback
	-rm -f $(DESTDIR)/var/run/flashback

#-------------------------------------------------------------------------------

# These are what you will call to build a Debian package and to clean it up.

debpkg:
	-debuild -us -uc

debclean:
	-rm -rf debian/flashback
	-rm -rf debian/flashback.debhelper.log
	-rm -rf debian/flashback.*.debhelper
	-rm -rf debian/flashback.substvars

#-------------------------------------------------------------------------------
# vim: noexpandtab


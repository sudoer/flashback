
#-------------------------------------------------------------------------------

# These are used internally by debuild.  "build" should be first.

build:

clean:

install:
	install -D -o root -g root -m 0755 src/flashback $(DESTDIR)/usr/sbin/flashback
	for f in flashback.conf flashback.jobs monitor-local.sh monitor-remote.sh ; do install -D -o root -g root -m 0644 examples/$$f $(DESTDIR)/usr/share/doc/flashback/examples/$$f ; done

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


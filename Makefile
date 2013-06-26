
#-------------------------------------------------------------------------------

# These are used internally by debuild.  "build" should be first.

build:

clean:

install:
	install -D -o root -g root -m 0755 src/flashback $(DESTDIR)/usr/sbin/flashback

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



#-------------------------------------------------------------------------------

# These are used internally by debuild.  "build" should be first.

build:

clean:

install:
	install -D -o root -g root -m 0755 src/greenback $(DESTDIR)/usr/sbin/greenback

#-------------------------------------------------------------------------------

# These are what you will call to build a Debian package and to clean it up.

debpkg:
	-debuild -us -uc

debclean:
	-rm -rf debian/greenback
	-rm -rf debian/greenback.debhelper.log
	-rm -rf debian/greenback.*.debhelper
	-rm -rf debian/greenback.substvars

#-------------------------------------------------------------------------------
# vim: noexpandtab


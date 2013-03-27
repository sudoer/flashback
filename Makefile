
build:

clean:

install:
	install -D -o root -g root -m 0755 src/greenback $(DESTDIR)/usr/sbin/greenback

debpkg:
	-debuild -us -uc

debclean:
	-rm -rf debian/greenback
	-rm -rf debian/greenback.debhelper.log
	-rm -rf debian/greenback.*.debhelper
	-rm -rf debian/greenback.substvars

# vim: noexpandtab


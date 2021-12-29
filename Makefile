export DESTARCH=arm
export PREFIX=/mmc
export FLOAT=soft

export EXTRACFLAGS = -O2 -pipe -march=armv7-a -mtune=cortex-a9
export PATH := /opt/tomatoware/$(DESTARCH)-$(FLOAT)$(subst /,-,$(PREFIX))/bin/:$(PATH)

rust:
	./scripts/rust.sh

clean:
	git clean -fdxq && git reset --hard

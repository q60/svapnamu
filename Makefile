NAME = svapnamu
TARGET = zig-out/bin/svapnamu

.PHONY: build test

all: build test

build:
	zigmod fetch
	zig build -Drelease-safe

test:
	$(TARGET)

install:
	install -Dm755 "$(TARGET)" "$(DESTDIR)/usr/bin/$(NAME)"
	install -Dm644 "LICENSE" "$(DESTDIR)/usr/share/licenses/$(NAME)/LICENSE"

uninstall:
	rm -rfv "$(DESTDIR)/usr/bin/$(NAME)" "$(DESTDIR)/usr/share/licenses/$(NAME)"

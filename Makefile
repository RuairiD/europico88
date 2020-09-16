pico8 = ~/pico-8/PICO-8.app/Contents/MacOS/pico8
carts_directory = ~/Library/Application\ Support/pico-8/carts/


.PHONY: p8
p8:
	python tools/tmxtomap.py map.tmx build/map.txt
	python tools/pngtogfx.py sprites.png build/gfx.txt
	tail -n +12 audio.p8 > build/audio.txt
	cat headers/lua_header.txt label.txt build/build.lua headers/gfx_header.txt build/gfx.txt headers/map_header.txt build/map.txt build/audio.txt > build/$(p8_filename)
	rm build/map.txt
	rm build/gfx.txt
	rm build/audio.txt


.PHONY: release
release:
	mkdir -p build
	make lua
	luamin -f build/game.lua > build/build.lua
	make p8 p8_filename=release.p8
	cp build/release.p8 $(carts_directory)


.PHONY: dev
dev:
	mkdir -p build
	make lua
	cat build/game.lua > build/build.lua
	make p8 p8_filename=dev.p8
	$(pico8) -run build/dev.p8


.PHONY: lua
lua:
	mkdir -p build
	find lib -type f -exec cat {} + > build/deps.lua
	cat build/deps.lua main.lua > build/game.lua
	rm build/deps.lua


.PHONY: audio
audio:
	$(pico8) -run audio.p8

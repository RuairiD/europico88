# PICO-8 Template
#### An oddly specific template for making and building PICO-8 games.

## Features
* `Makefile` with targets for dev and release builds (dev build assumes PICO-8 is running on MacOS)
* Uses [luamin](https://github.com/mathiasbynens/luamin) to minify code and keep filesize/character count trim. 
* .png to PICO-8 gfx conversion.
* [Tiled](https://github.com/bjorn/tiled) support, including .tmx to PICO-8 map conversion.
* Rudimentary dependency management to prevent `main.lua` getting cluttered.

## Installation
This template uses Python and Pillow for map and spritesheet conversion. A `virtualenv` is recommended.
```
virtualenv -p python3 venv
source venv/bin/activate
pip install -r requirements.txt
```

[luamin](https://github.com/mathiasbynens/luamin) must also be installed for `make release` to work. This step can be skipped if minification isn't considered necessary.
```
npm install -g luamin
```
Other installation methods can be found on its own README file.

## Building
* Both `make dev` and `make release` convert `sprites.png` to gfx data and `map.tmx` to map data, before concatenating them with code, sfx data and music data to form a runnable p8.
* `make release` minifies `main.lua` and any dependencies before building the `release.p8` file.
* `make dev` leaves code unchanged for debugging purposes, and also starts PICO-8 after building, running the built `dev.p8` file directly.
* When converting the `sprites.png` file into gfx data, if a pixel's colour is not part of PICO-8's palette, an eligible colour is chosen on a best-effort basis using [RGB distance](https://en.wikipedia.org/wiki/Color_difference#sRGB). These results can be a bit weird, so it's recommended to only use the PICO-8 palette in `sprites.png` anyway.

## Updating SFX and Music
A dummy `audio.p8` cart exists purely for SFX and music composition. Running `make audio` opens the audio cart in PICO-8. Running `save` in PICO-8 (without any filename) will write back any changes. The `make dev` and `make release` targets pull the SFX and music data from `audio.p8` when building the game. Both targets use `tail` to get the relevant cart section with SFX and music, and therefore rely on `audio.p8` having **nothing** but SFX and music. Any code, gfx or map data in the cart will likely cause the build to fail.

## Where can I set the .p8.png label?
`label.txt`

## Using dependencies
PICO-8 does not permit use of `require` or an alternative, so dependencies can't be imported in a conventional manner. The build scripts in this template will concatenate any files addded to the `lib/` directory onto the final `p8` cartridge, allowing `main.lua` to access them. PICO-8 specific dependencies should work out of the box (e.g. [pico8-bump](https://github.com/RuairiD/pico8-bump.lua)); others may need some modifications to work correctly...

#### Ensuring compatibility

Since `require` isn't used, dependencies shouldn't `return` anything e.g.
```
return {
    doSomethingUseful = function(x, y)
        ...
    end
    ...
}
```

This will cause the game to crash at runtime since there will be an unexpected `return` in the middle of the game. Instead, the returned object should be set as a variable which can then be accessed by `main.lua` after building. Usually this is as easy as replacing the `return` keyword with a variable assignment e.g.
```
-------------------
libs/my_library.lua
-------------------

local myLibrary = {
    doSomethingUseful = function(x, y)
        ...
    end
    ...
}

--------
main.lua
--------

...
function _init()
    ...
    myLibrary.doSomethingUseful(4, "farts")
    ...
end
...

```

A modified version of [classic](https://github.com/rxi/classic) (amended to remove the `return` statement as previously described) is included in `lib/` as I tend to use it in most projects for OOP. It can be safely removed if the project in question does not use or require it.

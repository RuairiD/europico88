import sys
from xml.etree import ElementTree


WIDTH = 128
HEIGHT = 32


def main(tmx_filename, map_filename):
    map_root = ElementTree.parse(tmx_filename).getroot()
    map_tiles_text = None
    for child in map_root:
        if child.tag == "layer":
            map_tiles_text = child[0].text
            break

    if not map_tiles_text:
        print("Could not find tiles in map file. Is this a Tiled .tmx file?")
        return

    output = ""
    for y in range(0, HEIGHT):
        lineout = ""
        tiles_line = map_tiles_text.splitlines()[y + 1]
        for x in range(0, WIDTH):
            tile = int(tiles_line.split(",")[x])
            if tile > 0:
                # Trim '0x' prefix.
                hextile = str(hex(tile - 1))[2:]
                # Decimal tile indices must be converted
                # to two digit hex values.
                if len(hextile) < 2:
                    hextile = '0' + hextile
                lineout += hextile
            else:
                lineout += '00'

        output += lineout + "\n"

    with open(map_filename, 'w') as outfile:
        outfile.write(output)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

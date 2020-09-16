import math
import sys
from PIL import Image


WIDTH = 128
HEIGHT = 128


PICO8_COLORS = [
    (0, 0, 0),
    (29, 43, 83),
    (126, 37, 83),
    (0, 135, 81),
    (171, 82, 54),
    (95, 87, 79),
    (194, 195, 199),
    (255, 241, 232),
    (255, 0, 77),
    (255, 163, 0),
    (255, 236, 39),
    (0, 228, 54),
    (41, 173, 255),
    (131, 118, 156),
    (255, 119, 168),
    (255, 204, 170),
]


def get_rgb_distance(rgb1, rgb2):
    r1, g1, b1 = rgb1
    r2, g2, b2 = rgb2
    return math.sqrt(
        (r1 - r2)**2 + (g1 - g2)**2 + (b2 - b2)**2,
    )


def get_closest_color_code(rgb):
    color_distances = (
        (candidate_rgb, get_rgb_distance(rgb, candidate_rgb))
        for candidate_rgb
        in PICO8_COLORS
    )
    return sorted(
        color_distances,
        key=lambda rgb_distance_pair: rgb_distance_pair[1],
    )[0][0]


def get_color_code(rgb):
    # Default will be black if no colour is found.
    try:
        color_code = PICO8_COLORS.index(rgb)
    except ValueError:
        color_code = PICO8_COLORS.index(get_closest_color_code(rgb))
    return str(hex(color_code))[2:]


def main(png_filename, gfx_filename):
    image = Image.open(png_filename).convert('RGB')
    pixel_map = image.load()

    output = ""
    for y in range(0, HEIGHT):
        lineout = ""
        for x in range(0, WIDTH):
            lineout += get_color_code(pixel_map[x, y])

        output += lineout + "\n"

    with open(gfx_filename, 'w') as outfile:
        outfile.write(output)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])


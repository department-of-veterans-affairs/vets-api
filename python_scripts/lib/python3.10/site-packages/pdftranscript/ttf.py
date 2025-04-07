#!/usr/bin/env python3
"""
Copied text from a PDF and pasted random symbols?

PDF files are sometimes purposely protected from copying,
but this often unintentionally prevents distribution and
findability of knowledge.
Another reason to embed fonts is to protect the font designs
themselves from copying.

This program is trying to recover that text and lost knowledge.

It recovers text in HTML produced by pdf2htmlEX from PDFs
where characters are broken due to embedded fonts
with bad character maps (CMAPs).

This allows to search and copy/paste the text.

The program works by comparing glyph shapes of the embedded
fonts with known fonts, so it is very helpful if the fonts
used in the PDF document are known and their full version
is available. This allows fully automatic repair of information.

If the fonts are unknown, unavailable, or glyphs can't be recognized,
program will ask the user to recognize the letter shape
and key in the right symbol.
It will only ask once for each shape and remember the letter choice
in a human-readable dictionary (dictionary.json).

The technical reason for random symbols:
Seemingly random characters are produced when you copy/paste text from PDF
because the PDF embedded fonts don't use standard unicode character code maps.
They use Private Use Area unicode range for mapping the glyph indices to codes.
"""

from lxml.html import tostring
import string
import glob
import json

try:
    from freetype import Face, FT_LOAD_RENDER, FT_LOAD_TARGET_MONO
except ImportError:
    print('Requires: pip3 install freetype-py')
try:
    from pdftranscript.config import FULL_FONTS_PATH
except ImportError:
    FULL_FONTS_PATH = './fonts'

DEBUG = 1


def pua_content(txt):
    """Ratio of characters encoded using Private Use Area (PUA) E000—F8FF.
    PUA is used by PDF embedded fonts if original CMAP was thrown away."""

    return len([1 for x in txt if 0xE000 <= ord(x) <= 0xF8FF]) / float(len(txt))


def bits(x):
    data = []
    for _i in range(8):
        data.insert(0, int((x & 1) == 1))
        x = x >> 1
    return data


def show_glyph(data, bitmap, draw=True):
    """Render glyph on the CLI using TEXT art"""

    w = ''.join(['█ ' if px else '  ' for px in data])
    ls = []
    s = ''
    for index, e in enumerate(w):
        if (index + 1) % (bitmap.width * 2) == 0:
            ls.append(s)
            s = ''
        else:
            s += e
    return ls


def glyph_data(face, char):
    face.set_char_size(32 * 48)  # 24*32, 32*48, 48*64
    face.load_char(char, FT_LOAD_RENDER | FT_LOAD_TARGET_MONO)
    bitmap = face.glyph.bitmap
    # width = face.glyph.bitmap.width
    # rows = face.glyph.bitmap.rows
    # pitch = face.glyph.bitmap.pitch
    data = []
    for i in range(bitmap.rows):
        row = []
        for j in range(bitmap.pitch):
            row.extend(bits(bitmap.buffer[i * bitmap.pitch + j]))
        data.extend(row[: bitmap.width])
    return data, bitmap


def load_fonts(path):
    # TODO: WOFF handling
    fonts = glob.glob(path + '/*.ttf')  # + glob.glob(path+'/*.woff')
    fonts = {x.split('/')[-1].replace('.ttf', ''): Face(x) for x in fonts}
    if DEBUG:
        print('Loading fonts from: ' + path)
        for face in fonts.values():
            print(face.family_name.decode(), face.style_name.decode(), face.num_glyphs, 'glyphs')
    return fonts


def char_lookup(fonts):
    chars = string.printable + "£©¹’'‘’“”"
    ls = []
    for _name, font in fonts.items():
        for char in chars:
            data, bitmap = glyph_data(font, char)
            ls.append((str(data), char))
    return dict(ls)


def lookup_user(data, bitmap):
    dictionary = 'dictionary.json'
    try:
        lookup = json.load(open(dictionary, 'r'))
    except ValueError:  # dictionary was empty
        lookup = []
    shape = show_glyph(data, bitmap)
    try:  # lookup shape in our dictionary
        return [c for c, s in lookup if s == shape][0]
    except IndexError:  # No known character - ask for input
        for line in shape:
            print(line)
        print('\a')
        char = input('Please enter character shown: ')
        print('you entered: ', char)
        lookup.append((char, shape))
        lookup = sorted(lookup, key=lambda x: x[0])
        json.dump(lookup, open(dictionary, 'w+'), indent=1, ensure_ascii=False)
        return char


LOOKUP_FONTS = char_lookup(load_fonts(FULL_FONTS_PATH))


def decode_font(code, font, embed_fonts):
    word = ''
    for codepoint in code:
        data, bitmap = glyph_data(embed_fonts[font], codepoint)
        try:
            char = LOOKUP_FONTS[str(data)]
        except KeyError:
            char = lookup_user(data, bitmap)
        word += char
    # print(font, len(code), word)
    return word


def font_family(e):
    def fn(e):
        if e is None:
            return
        css = e.get('class', '')
        if css.startswith('ff'):
            return css[1:3]
        try:
            return 'f' + css.split(' ff')[1][0]
        except IndexError:
            return

    ancestors = [e]
    if e is not None:
        ancestors += [x for x in e.iterancestors()]
    for w in ancestors:
        f = fn(w)
        if f:
            return f
    return 'f1'


def recover_text(dom, embed_fonts_path):
    embed_fonts = load_fonts(embed_fonts_path)
    for e in dom.iter():
        text_ff = font_family(e)
        tail_ff = font_family(e.getparent())

        def decode(txt, font):
            return decode_font(txt, font, embed_fonts)

        # element text and tail(txt following el) can be different font-family
        # only decode text its font-family is embedded font
        if e.text and e.text != ' ' and text_ff in embed_fonts.keys():
            e.text = decode(e.text, text_ff)
        if e.tail and e.tail is not None and tail_ff in embed_fonts.keys():
            e.tail = decode(e.tail, tail_ff)


if __name__ == '__main__':
    from pdftranscript import transcript, config
    import os.path

    doc_path = config.HTML_DIR + '/100026_945655/100026_945655.html'
    dom, css = transcript.prepare(doc_path)
    recover_text(dom, os.path.dirname(doc_path))
    f = open(doc_path.replace('.html', '.htm'), 'wb+')
    f.write(tostring(dom))
    f.close()

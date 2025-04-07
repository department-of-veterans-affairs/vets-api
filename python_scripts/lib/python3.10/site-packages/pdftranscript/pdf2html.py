#!/usr/bin/env python3
"""
PDF to HTML conversion - first step of the process.
Batch processes a folder full of PDFs using pdf2htmlEX
producing an HTML folder.

This HTML uses just CSS positioning for layout. We need
further work to add semantic tags: transcript.py
"""

import glob
import multiprocessing
import os
import time
from pathlib import Path

from pdftranscript import config


def pdf2html(pdf_path):
    """Generates a long command"""

    fn = Path(pdf_path).name.replace('.pdf', '')
    # --embed cfijo = don't embed Css, Fonts, Images, Js, Outlines
    # > man pdf2htmlEX
    if config.DOCKER_INSTALL:
        # get the user id and group id of the current user
        user_id = os.getuid()
        group_id = os.getgid()
        pdf2htm = f'docker run -ti --rm -v {config.DATA_DIR}:/pdf -w /pdf --user={user_id}:{group_id} {config.DOCKER_IMG_TAG}'
        out_dir = '/pdf/HTML'
        pdf_path = pdf_path.replace(config.PDF_DIR, '/pdf/PDF')
        hint = ''
    else:
        pdf2htm = 'pdf2htmlEX'
        out_dir = config.HTML_DIR
        hint = ' --external-hint-tool ttfautohint'

    cmd = f'{pdf2htm} --embed-external-font 0 {hint} --process-nontext 0 --embed cfijo ' +\
          f'--dest-dir {os.path.join(out_dir, fn)} {pdf_path} {fn}.html'
    print()
    print(cmd)
    os.system(cmd)
    time.sleep(0.2)


if __name__ == '__main__':
    os.makedirs(config.HTML_DIR, exist_ok=True)
    p = multiprocessing.Pool(4)
    pdfs = glob.glob(config.PDF_DIR + '/*.pdf')
    p.map(pdf2html, pdfs)

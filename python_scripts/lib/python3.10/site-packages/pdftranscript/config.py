"""
Set your environment variables in your .env file e.g.:
DATA_DIR=/path/to/PDFtranscript/tests
DOCKER_INSTALL=1
"""

import os
import os.path
from dotenv import load_dotenv

load_dotenv()

# This is your project root, configure your own path.
DATA_DIR = os.getenv('DATA_DIR', 'tests/')  # /path/to/your/data/dir
# PDF folder within your project root. PDFs to convert come from here.
PDF_DIR = os.path.join(DATA_DIR, 'PDF')
# HTML folder is where pdf2htmlEX outputs (non-semantic HTML)
# after running `./pdf2html.py`.
HTML_DIR = os.path.join(DATA_DIR, 'HTML')
# used by ttf.py to access full original fonts to compare with the broken ones
FULL_FONTS_PATH = os.getenv('FULL_FONTS_PATH', '/path/to/truetype/fonts/')

DOCKER_INSTALL = bool(int(os.getenv('DOCKER_INSTALL', 0)))
DOCKER_IMG_TAG = os.getenv(
    'DOCKER_IMG_TAG', 'pdf2htmlex/pdf2htmlex:0.18.8.rc2-master-20200820-ubuntu-20.04-x86_64'
)
# remove mumbo-jumbo TEXT strings before HTML processing (regexes or text)
REMOVE_BEFORE = (
    # r'The Office for Standards.*?www\.ofsted\.gov\.uk',
    # r'Any complaints.*?\@ofsted\.gov\.uk',
    # r'© Crown copyright 20\d\d',
    # r'Inspection grades:.*?inspection terms',
    # r'This letter.*?their school\.',
    # r'You can use Parent View.*?www\.ofsted\.gov\.uk'
)
# find and replace after HTML processing finished
REPLACE_AFTER = (
    # (r'td>( )?Overall effectiveness j',
    #  'td colspan=4>Overall effectiveness j'),
)
# Additional bullet point characters to be expected at start of line for <li>
# Copied out of the processed PDF. Common bullets are pre-programmed.
BULLETS = ('', '')

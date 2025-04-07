#!/usr/bin/env python3
from pdftranscript import transcript, config
import os
import os.path


def preview(stem):
    path = config.HTML_DIR + f'/{stem}/{stem}.html'
    transcript.semanticize(path)
    result = os.path.dirname(path).replace('HTML', 'HTM') + '.htm'
    os.system('firefox ' + result)
    # on OS X
    # os.system('open -a safari file://' + result)


for test in [
    'design-heavy',
    'report',
    'research-paper',
    'technical-2col',
    'vol2a',
]:
    preview(test)

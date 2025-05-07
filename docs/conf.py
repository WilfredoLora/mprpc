#
# mprpc documentation build configuration file.
#

import sys
import os
import re

# -- General configuration ------------------------------------------------

extensions = [
    'sphinx.ext.autodoc',
]

templates_path = ['_templates']
source_suffix = '.rst'
master_doc = 'index'

project = 'mprpc'
copyright = '2013, Studio Ousia'

# Parse version from setup.py (legacy method; optional improvement: use __version__ in package)
release = re.search("version='([^']+)'",
    open(os.path.join(os.path.dirname(__file__), os.pardir,
         'setup.py')).read().strip()
).group(1)
version = '.'.join(release.split('.')[:2])

exclude_patterns = ['_build']
pygments_style = 'sphinx'

# -- Options for HTML output ----------------------------------------------

html_theme = 'alabaster'
html_static_path = ['_static']

# -- Options for LaTeX output ---------------------------------------------

latex_documents = [
  ('index', 'mprpc.tex', 'mprpc Documentation',
   'Studio Ousia', 'manual'),
]

# -- Options for manual page output ---------------------------------------

man_pages = [
    ('index', 'mprpc', 'mprpc Documentation',
     ['Studio Ousia'], 1)
]

# -- Options for Texinfo output -------------------------------------------

texinfo_documents = [
  ('index', 'mprpc', 'mprpc Documentation',
   'Studio Ousia', 'mprpc', 'One line description of project.',
   'Miscellaneous'),
]

project = "wf-human-variation"
author = "wf-human-variation maintainers"
copyright = "2026, wf-human-variation maintainers"

extensions = [
    "sphinx.ext.autosectionlabel",
]

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

html_theme = "alabaster"
html_static_path = ["_static"]

autosectionlabel_prefix_document = True
nitpicky = True

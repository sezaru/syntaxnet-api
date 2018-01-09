Dockerized SyntaxNet POS Tagger API
===================================
A small HTTP API for SyntaxNet POS Tagger under Apache 2 Licence.
Based on version available `here<http://syntaxnet.askplatyp.us>`.

Currently only provides a way to call Parsey trained with universal dependencies.

The API documentation is availlable as a Swagger API description via web browser access to root domain.

Are available languages with the following Universal Dependencies training sets:

* grc: Ancient_Greek-PROIEL
* eu: Basque
* bg: Bulgarian
* zh: Chinese
* hr: Croatian
* cs: Czech
* da: Danish
* nl: Dutch
* en: English
* et: Estonian
* fi: Finnish
* fr: French
* gl: Galician
* de: German
* el: Greek
* he: Hebrew
* hi: Hindi
* hu: Hungarian
* id: Indonesian
* it: Italian
* la: Latin-PROIEL
* no: Norwegian
* pl: Polish
* pt: Portuguese
* sl: Slovenian
* es: Spanish
* sv: Swedish

**SCOPE:  [New Product Development]**

**TARGET: [Accesory Product Development]**

**STATUS: [Production Ready]**

Notes:
------
This project relies on Git submodules, so remember using ``--recursive`` tag when cloning.

In case you want to deploy it with Docker, you should take into account that this project Dockerfile includes commands for tensorflow compilation, so build phase will take some time. In case you wanted to modify anything regarding the deployment phase, maybe you should consider splitting the Dockerfile, in order to avoid repeating compilation multiple times.

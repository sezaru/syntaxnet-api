Dockerized SyntaxNet POS Tagger API
===================================
**NOTE**: this is a fork from `https://github.com/danielperezr88/syntaxnet-api` which I've adapted to use the docker version with only Chinese, English, French, German, Italian, Portuguese and Spanish. The reason is to save memory and space. This repository heavily relies on the previous work done by `https://github.com/davidsbatista/syntaxnet-api`.

A small HTTP API for SyntaxNet POS Tagger under Apache 2 Licence.
Based on version available `here<http://syntaxnet.askplatyp.us>`.

Currently only provides a way to call Parsey trained with universal dependencies.

The API documentation is availlable as a Swagger API description via web browser access to root domain.

Are available languages with the following Universal Dependencies training sets:

* zh: Chinese
* en: English
* fr: French
* de: German
* it: Italian
* pt: Portuguese
* es: Spanish

**SCOPE:  [New Product Development]**

**TARGET: [Accesory Product Development]**

**STATUS: [Production Ready]**

Notes:
------
This project relies on Git submodules, so remember using ``--recursive`` tag when cloning.

In case you want to deploy it with Docker, you should take into account that this project Dockerfile includes commands for tensorflow's syntaxnet compilation, so build phase will take some time. In case you wanted to modify anything regarding the deployment phase, maybe you should consider splitting the Dockerfile, in order to avoid repeating compilation multiple times.


Creating the Docker Image

    git clone https://github.com/r3dlex/syntaxnet-api
    cd syntaxnet-api
    docker build . -t syntaxnet-api

Running the Docker Image

    docker run -p 7000:7000 IMAGE_ID

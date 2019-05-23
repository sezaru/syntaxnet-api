"""
Copyright 2016 Thomas Pellissier Tanon All Rights Reserved.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""
import logging

from flask import Flask, request, jsonify, redirect
from flask_swaggerui import build_static_blueprint, render_swaggerui
from werkzeug.exceptions import BadRequest

import requests as req

import parsey

# Flask setup
_flask_app = Flask(__name__)
logging.basicConfig(level=logging.INFO)


def generate_url(host, protocol='http', port=80, dir=''):

    if isinstance(dir, list):
        dir = '/'.join(dir)

    return "%s://%s:%d/%s" % (protocol, host, port, dir)

MY_IP = req.get(generate_url('jsonip.com')).json()['ip']
PORT = 7000


@_flask_app.route('/')
def _root():
    return redirect('/v1')


@_flask_app.route('/v1')
def _v1():
    return render_swaggerui(swagger_spec_path='/v1/swagger.json')


@_flask_app.route('/v1/parsey-universal-full', methods=['POST'])
def _parsey_universal_full_handler():
    text = request.get_data()
    language_code = request.headers.get('Content-Language', 'en').lower()
    print(text)
    print(language_code)

    try:
        conllu = parsey.parsey_universal_full_conllu(text, language_code)
        return _flask_app.response_class(conllu, mimetype='text/plain; charset=utf-8')
    except ValueError as e:
        raise BadRequest(e)


@_flask_app.route('/v1/swagger.json')
def _v1_spec():
    return jsonify({
        'swagger': '2.0',
        'info': {
            'version': 'dev',
            'title': 'Simple API for SyntaxNet',
            'description': 'Allows to do HTTP request to execute NLP processing using SyntaxNet',
            'license': {
                'name': 'Apache 2.0',
                'url': 'http://www.apache.org/licenses/LICENSE-2.0.html'
            }
        },
        'host': MY_IP+':'+str(PORT),
        'basePath': '/v1',
        'paths': {
            '/parsey-universal-full': {
                'post': {
                    'tags': ['Parsey Universal'],
                    'summary': 'Executes the full parsing pipeline against Parsey Universal',
                    'description': 'See also https://github.com/tensorflow/models/blob/master/syntaxnet/universal.md',
                    'parameters': [
                        {
                            'name': 'text',
                            'in': 'body',
                            'description': 'The text to parse',
                            'required': True,
                            'schema': {
                                'type': 'string'
                            }
                        },
                        {
                            'name': 'Content-Language',
                            'in': 'header',
                            'description': 'The text language.',
                            'required': True,
                            'type': 'string',
                            'enum': ['pt']
                        }
                    ],
                    'consumes': [
                        'text/plain; charset=utf-8'
                    ],
                    'produces': [
                        'text/plain; charset=utf-8'
                    ],
                    'responses': {
                        '200': {
                            'description': 'The parsing result in the CoNLL-U format http://universaldependencies.org/format.html'
                        },
                        '400': {
                            'description': 'Bad request, usually because the Content-Language is not supported'
                        }
                    }
                }
            }
        }
    })


_flask_app.register_blueprint(build_static_blueprint('swaggerui', __name__))

_flask_app.run(port=PORT, host='0.0.0.0')

FROM ubuntu:19.04 AS download_dependencies

MAINTAINER sezaru <sezdocs@live.com>

RUN apt-get update \
 && apt-get install -y \
      build-essential \
      curl \
      g++ \
      git \
      libfreetype6-dev \
      libpng-dev \
      libzmq3-dev \
      openjdk-8-jdk \
      pkg-config \
      python-dev \
      python-numpy \
      python-pip \
      software-properties-common \
      swig \
      unzip \
      zip \
      zlib1g-dev \
      libcurl3-dev \
      wget \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN update-ca-certificates -f

FROM download_dependencies AS setup_bazel

# Running bazel inside a `docker build` command causes trouble, cf:
#   https://github.com/bazelbuild/bazel/issues/134
# The easiest solution is to set up a bazelrc file forcing --batch.
RUN echo "startup --batch" >>/root/.bazelrc

# Similarly, we need to workaround sandboxing issues:
#   https://github.com/bazelbuild/bazel/issues/418
RUN echo "build --spawn_strategy=standalone --genrule_strategy=standalone" >>/root/.bazelrc

ENV BAZELRC /root/.bazelrc

ENV BAZEL_VERSION 0.3.2

WORKDIR /

RUN mkdir /bazel \
 && cd /bazel \
 && curl -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh \
 && chmod +x bazel-*.sh \
 && ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh \
 && cd / \
 && rm -f /bazel

FROM setup_bazel AS clone_syntaxnet

COPY syntaxnet-api syntaxnet-api

#RUN git clone --depth 1 --recursive https://github.com/sezaru/syntaxnet-api.git \
# && cd /syntaxnet-api \
# && git submodule update --init --recursive

FROM clone_syntaxnet AS syntaxnet_dependencies

RUN pip install -U protobuf==3.1.0
RUN pip install asciitree
RUN pip install mock

FROM syntaxnet_dependencies AS patch_syntaxnet

COPY fix_workspace.bzl.patch /syntaxnet-api/tensorflow-models/syntaxnet/tensorflow/tensorflow/fix_workspace.bzl.patch

RUN cd /syntaxnet-api/tensorflow-models/syntaxnet/tensorflow/tensorflow \
 && patch -p0 < fix_workspace.bzl.patch

FROM patch_syntaxnet AS configure_syntaxnet

RUN cd /syntaxnet-api/tensorflow-models/syntaxnet/tensorflow \
 && echo "\ny\n\n\n\n" | ./configure

FROM configure_syntaxnet AS build_syntaxnet

RUN cd /syntaxnet-api/tensorflow-models/syntaxnet \
 && bazel test syntaxnet/... util/utf8/...

FROM build_syntaxnet AS download_models

RUN mkdir /syntaxnet-api/tensorflow-models/syntaxnet/universal_models \
 && cd /syntaxnet-api/tensorflow-models/syntaxnet/universal_models \
 && for LANG in Portuguese; do \
      wget http://download.tensorflow.org/models/parsey_universal/${LANG}.zip; \
      unzip ${LANG}.zip; \
      rm ${LANG}.zip; \
    done

FROM ubuntu:19.04 as final
#FROM download_models AS python3_syntaxnet_dependencies

RUN mkdir -p /syntaxnet-api/tensorflow-models/syntaxnet

COPY --from=download_models /syntaxnet-api/tensorflow-models/syntaxnet/* /syntaxnet-api/tensorflow-models/syntaxnet/
COPY --from=download_models /syntaxnet-api/parsey.py /syntaxnet-api/parsey.py
COPY --from=download_models /syntaxnet-api/flask_server.py /syntaxnet-api/flask_server.py
COPY --from=download_models /syntaxnet-api/requirements.txt /syntaxnet-api/requirements.txt

RUN apt-get update \
 && apt-get -y install python3-pip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN cd /syntaxnet-api \
 && pip3 install -r requirements.txt

#FROM python3_syntaxnet_dependencies AS finishing_steps

WORKDIR /syntaxnet-api/

CMD python3 flask_server.py

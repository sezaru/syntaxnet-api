FROM ubuntu:19.04 AS download_dependencies

MAINTAINER Eduardo Barreto Alexandre <sezdocs@live.com>

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
      libcurl4-openssl-dev \
      wget

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
 && rm -rf /bazel

FROM setup_bazel AS clone_syntaxnet

RUN git clone --depth 1 --recursive https://github.com/sezaru/syntaxnet-api.git \
 && cd /syntaxnet-api \
 && git submodule update --init --recursive

FROM clone_syntaxnet AS patch_syntaxnet

COPY fix_workspace.bzl.patch \
  /syntaxnet-api/tensorflow-models/syntaxnet/tensorflow/tensorflow/fix_workspace.bzl.patch

RUN cd /syntaxnet-api/tensorflow-models/syntaxnet/tensorflow/tensorflow \
 && patch -p0 < fix_workspace.bzl.patch \
 && rm fix_workspace.bzl.patch

COPY fix_tensorflow_configure_to_find_libcurl.patch \
  /syntaxnet-api/tensorflow-models/syntaxnet/tensorflow/fix_tensorflow_configure_to_find_libcurl.patch

RUN cd /syntaxnet-api/tensorflow-models/syntaxnet/tensorflow \
 && patch -p0 < fix_tensorflow_configure_to_find_libcurl.patch \
 && rm fix_tensorflow_configure_to_find_libcurl.patch

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

FROM ubuntu:19.04 AS final_dependecies

RUN apt-get update \
 && apt-get -y install python3-pip python-pip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN pip3 install Flask flask-swaggerui requests \
 && pip install numpy mock protobuf==3.1.0 asciitree

FROM final_dependecies AS final_copy_syntaxnet

RUN mkdir -p /syntaxnet-api/tensorflow-models/syntaxnet

COPY --from=download_models /syntaxnet-api/tensorflow-models/syntaxnet \
  /syntaxnet-api/tensorflow-models/syntaxnet
COPY --from=download_models /syntaxnet-api/parsey.py /syntaxnet-api/parsey.py
COPY --from=download_models /syntaxnet-api/flask_server.py /syntaxnet-api/flask_server.py
COPY --from=download_models /syntaxnet-api/requirements.txt /syntaxnet-api/requirements.txt

RUN mkdir -p /root/.cache/bazel
RUN mkdir -p /bazel_temp

COPY --from=download_models /root/.cache/bazel /bazel_temp/ 

RUN bazel_bin_path=$(realpath -m /syntaxnet-api/tensorflow-models/syntaxnet/bazel-bin) \
 && mkdir -p ${bazel_bin_path%/*} \
 && cp -r "/bazel_temp/${bazel_bin_path#/*/*/*/}" $bazel_bin_path

RUN bazel_genfiles_path=$(realpath -m /syntaxnet-api/tensorflow-models/syntaxnet/bazel-genfiles) \
 && mkdir -p ${bazel_genfiles_path%/*} \
 && cp -r "/bazel_temp/${bazel_genfiles_path#/*/*/*/}" $bazel_genfiles_path

RUN bazel_syntaxnet_path=$(realpath -m /syntaxnet-api/tensorflow-models/syntaxnet/bazel-syntaxnet) \
 && mkdir -p ${bazel_syntaxnet_path%/*} \
 && cp -r "/bazel_temp/${bazel_syntaxnet_path#/*/*/*/}" $bazel_syntaxnet_path

RUN bazel_out_path=$(realpath -m /syntaxnet-api/tensorflow-models/syntaxnet/bazel-out) \
 && mkdir -p ${bazel_out_path%/*} \
 && cp -r "/bazel_temp/${bazel_out_path#/*/*/*/}" $bazel_out_path

RUN bazel_testlogs_path=$(realpath -m /syntaxnet-api/tensorflow-models/syntaxnet/bazel-testlogs) \
 && mkdir -p ${bazel_testlogs_path%/*} \
 && cp -r "/bazel_temp/${bazel_testlogs_path#/*/*/*/}" $bazel_testlogs_path

RUN bazel_bin_path=$(realpath -m /syntaxnet-api/tensorflow-models/syntaxnet/bazel-bin) \
 && external_path="${bazel_bin_path%/*/*/*/*/*}/external" \
 && cp -r "/bazel_temp/${external_path#/*/*/*/}" $external_path

RUN rm -rf /bazel_temp

FROM final_copy_syntaxnet AS final

WORKDIR /syntaxnet-api/

CMD python3 flask_server.py

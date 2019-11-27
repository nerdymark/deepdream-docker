# Copyright 2014 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM ubuntu:bionic

# Cuda stuff
RUN apt-get update && apt-get install -y --no-install-recommends \
gnupg2 curl ca-certificates && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list && \
    echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/nvidia-ml.list && \
    apt-get purge --autoremove -y curl && \
rm -rf /var/lib/apt/lists/*

ENV CUDA_VERSION 10.2.89

ENV CUDA_PKG_VERSION 10-2=$CUDA_VERSION-1

# For libraries in the cuda-compat-* package: https://docs.nvidia.com/cuda/eula/index.html#attachment-a
RUN apt-get update && apt-get install -y --no-install-recommends \
        cuda-cudart-$CUDA_PKG_VERSION \
cuda-compat-10-2 && \
ln -s cuda-10.2 /usr/local/cuda && \
    rm -rf /var/lib/apt/lists/*

# Required for nvidia-docker v1
RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV NVIDIA_REQUIRE_CUDA "cuda>=10.2 brand=tesla,driver>=384,driver<385 brand=tesla,driver>=396,driver<397 brand=tesla,driver>=410,driver<411"

# My local Apt proxy. Uncomment if you're not on my LAN.
ADD 01proxy /etc/apt/apt.conf.d/01proxy

RUN mkdir /deepdream
WORKDIR /deepdream

RUN export DEBIAN_FRONTEND=noninteractive

RUN ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
RUN apt-get -q update && \
  apt-get install -y apt-utils && \
  apt-get install -y tzdata && \
  dpkg-reconfigure --frontend noninteractive tzdata

RUN apt-get -q update && \
  apt-get install --no-install-recommends -y -q \
    build-essential \
    ca-certificates \
    git \
    python python-pip \
    python-dev libpython-dev \
    python-numpy python-scipy python-pil \
    ipython \
    libprotobuf-dev libleveldb-dev libsnappy-dev libopencv-dev libhdf5-serial-dev libboost-all-dev \
    libatlas-base-dev libgflags-dev libgoogle-glog-dev liblmdb-dev protobuf-compiler \
    software-properties-common \
    libhdf5-100 libhdf5-serial-dev libhdf5-dev libhdf5-cpp-100 && \
  add-apt-repository ppa:mc3man/bionic-media -y && \
  apt-get update && \
  apt-get install ffmpeg -y && \
  apt-get clean && \
  pip install wheel && \
  pip install setuptools && \
  pip install jupyter && \
  pip install imageio && \
  pip install moviepy && \
  rm /var/lib/apt/lists/*_*

# Download and compile Caffe
RUN git clone https://github.com/BVLC/caffe
RUN cd caffe && \
  cp Makefile.config.example Makefile.config && echo "CPU_ONLY := 0" >> Makefile.config && \
  make all -j4 
RUN pip install -U pip
RUN pip install cython jupyter
RUN cd caffe && \
  pip install --requirement python/requirements.txt 
RUN cd caffe && make pycaffe -j2
RUN cd caffe && make distribute
RUN cd caffe/scripts && ./download_model_binary.py ../models/bvlc_googlenet/

RUN pip install protobuf && pip install tornado --upgrade
RUN apt-get -q update && \
  apt-get install --no-install-recommends -y --force-yes -q \
    python-jsonschema && \
  apt-get clean && \
  rm /var/lib/apt/lists/*_*

RUN git clone https://github.com/google/deepdream

# Uncomment to include DeepDream Video
RUN git clone https://github.com/graphific/DeepDreamVideo
RUN cd DeepDreamVideo && chmod a+x *.py

ENV LD_LIBRARY_PATH=/deepdream/caffe/distribute/lib
ENV PYTHONPATH=/deepdream/caffe/distribute/python

EXPOSE 8888

ADD start.sh start.sh

CMD ["./start.sh"]

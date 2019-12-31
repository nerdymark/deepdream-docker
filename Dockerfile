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

ENV DEBIAN_FRONTEND=noninteractive

# My local Apt proxy. Uncomment if you're not on my LAN.
ADD 01proxy /etc/apt/apt.conf.d/01proxy

# Keyboard configuration
ENV TERM xterm
ADD keyboard /etc/default/keyboard

RUN apt-get update && apt-get dist-upgrade -y 

# Cuda stuff
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg2 curl ca-certificates && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - && \
    echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list && \
    echo "deb http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/nvidia-ml.list
    # apt-get purge --autoremove -y curl && \
    # rm -rf /var/lib/apt/lists/*

ENV CUDA_VERSION 10.2.89

ENV CUDA_PKG_VERSION 10-2=$CUDA_VERSION-1

# For libraries in the cuda-compat-* package: https://docs.nvidia.com/cuda/eula/index.html#attachment-a
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        cuda \
        cuda-cudart-$CUDA_PKG_VERSION \
        cuda-compat-10-2 && \
    ln -fs /usr/local/cuda-10.2 /usr/local/cuda && \
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
ENV CUDA_ARCH_BIN "35 52 60 61 70"
ENV CUDA_ARCH_PTX "70"

RUN ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime

RUN apt-get -q update && \
  apt-get install -y apt-utils && \
  apt-get install -y tzdata && \
  dpkg-reconfigure --frontend noninteractive tzdata

RUN apt install -y python python3 python-pip python3-pip \
    python-dev libpython-dev \
    python3-dev libpython3-dev \
    python-numpy python-scipy python-pil \
    python3-numpy python3-scipy python3-pil 

RUN pip install python-dateutil --upgrade
RUN pip3 install python-dateutil --upgrade

RUN apt install -y libcurl4-openssl-dev libssl-dev

RUN apt install -y python-cairo libcairo2-dev libgirepository1.0-dev python3-pycurl

RUN pip3 install --upgrade tensorflow-gpu tensorboard

RUN pip3 install gpt-2-simple

RUN apt install -y git-core wget

RUN apt-get -q update && \
  apt-get install --no-install-recommends -y -q \
    build-essential \
    ca-certificates \
    git \
    ipython \
    ipython3 \
    libprotobuf-dev libleveldb-dev libsnappy-dev libopencv-dev libhdf5-serial-dev libboost-all-dev \
    libatlas-base-dev libgflags-dev libgoogle-glog-dev liblmdb-dev protobuf-compiler \
    software-properties-common \
    libboost-dev libboost-all-dev \
    libhdf5-100 libhdf5-serial-dev libhdf5-dev libhdf5-cpp-100 && \
  add-apt-repository ppa:mc3man/bionic-media -y && \
  apt-get update && \
  apt-get install ffmpeg -y && \
  apt-get clean && \
  pip3 install wheel && \
  pip3 install setuptools && \
  pip install setuptools && \
  pip3 install imageio && \
  pip3 install moviepy && \
  pip3 install tables && \
  pip3 install h5py && \
  pip3 install fire && \
  pip3 install regex && \
  pip3 install requests && \
  pip3 install tqdm && \
  pip3 install pyyaml && \
  rm /var/lib/apt/lists/*_*

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    lbzip2 \
    libfftw3-dev \
    libgdal-dev \
    libgeos-dev \
    libgsl0-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libhdf4-alt-dev \
    libhdf5-dev \
    libjq-dev \
    liblwgeom-dev \
    libpq-dev \
    libproj-dev \
    libprotobuf-dev \
    libnetcdf-dev \
    libsqlite3-dev \
    libssl-dev \
    libudunits2-dev \
    netcdf-bin \
    postgis \
    protobuf-compiler \
    sqlite3 \
    tk-dev \
    unixodbc-dev 

RUN ldconfig

RUN mkdir /deepdream
WORKDIR /deepdream

# Download and compile Caffe
RUN git clone https://github.com/nerdymark/caffe.git
RUN cd caffe && \
  cp Makefile.config.example Makefile.config && echo "CPU_ONLY := 0" >> Makefile.config && \
  make all -j4 
RUN pip install -U pip

RUN cd caffe && \
  pip3 install --requirement python/requirements.txt 
RUN cd caffe && make pycaffe -j2
RUN cd caffe && make distribute
RUN pip install pyyaml
RUN cd caffe/scripts && ./download_model_binary.py ../models/bvlc_googlenet/

RUN pip3 install protobuf && pip3 install tornado --upgrade
RUN apt-get -q update && \
  apt-get install --no-install-recommends -y --force-yes -q \
    python-jsonschema && \
  apt-get clean && \
  rm /var/lib/apt/lists/*_*

RUN git clone https://github.com/google/deepdream

# Uncomment to include DeepDream Video
WORKDIR /deepdream/deepdream
RUN git clone https://github.com/graphific/DeepDreamVideo
RUN cd DeepDreamVideo && chmod a+x *.py

ENV LD_LIBRARY_PATH=/deepdream/caffe/distribute/lib
ENV PYTHONPATH=/deepdream/caffe/distribute/python

EXPOSE 8888

WORKDIR /deepdream
ADD start.sh start.sh

ADD GifMaker.ipynb /deepdream/deepdream/GifMaker.ipynb

RUN mkdir ~/.jupyter

RUN echo "c.NotebookApp.ip = '0.0.0.0'" >> ~/.jupyter/jupyter_notebook_config.py

RUN mkdir /deepdream/deepdream/gpt-2
WORKDIR /deepdream/deepdream/gpt-2
ADD src /deepdream/deepdream/gpt-2
ADD download_model.py /deepdream/deepdream/gpt-2
ADD domains.txt /deepdream/deepdream/gpt-2
ADD model_card.md /deepdream/deepdream/gpt-2


RUN python3 download_model.py 124M
#RUN python download_model.py 355M
#RUN python download_model.py 774M
#RUN python download_model.py 1558M

RUN pip3 install jupyter

RUN ipython kernelspec install-self
RUN ipython3 kernelspec install-self

#RUN apt-get clean


WORKDIR /deepdream
CMD ["./start.sh"]

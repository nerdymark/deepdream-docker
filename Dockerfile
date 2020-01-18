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

ARG consumer_key
ARG consumer_secret
ARG access_token
ARG access_token_secret

# My local Apt proxy. Uncomment if you're not on my LAN.
ADD 01proxy /etc/apt/apt.conf.d/01proxy

# Keyboard configuration
ENV TERM xterm
ADD keyboard /etc/default/keyboard

RUN apt-get update
RUN apt-get -y install software-properties-common
RUN add-apt-repository universe -y
RUN add-apt-repository multiverse -y

RUN apt-get -y install locales-all
RUN touch /usr/share/locale/locale.alias

# Set the locale
# RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
#     locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8    

ENV PYTHONIOENCODING=utf8
RUN apt-get update && apt-get dist-upgrade -y 

## FROM CUDA 10.0 base 


RUN apt-get update && apt-get install -y --no-install-recommends gnupg2 curl ca-certificates && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list && \
    echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/nvidia-ml.list && \
    apt-get purge --autoremove -y curl && \
    rm -rf /var/lib/apt/lists/*

ENV CUDA_VERSION 10.0.130

ENV CUDA_PKG_VERSION 10-0=$CUDA_VERSION-1

# For libraries in the cuda-compat-* package: https://docs.nvidia.com/cuda/eula/index.html#attachment-a
RUN apt-get update && apt-get install -y --no-install-recommends \
        cuda-cudart-$CUDA_PKG_VERSION \
        cuda-compat-10-0 && \
    ln -s cuda-10.0 /usr/local/cuda && \
    rm -rf /var/lib/apt/lists/*

# Required for nvidia-docker v1
RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV NVIDIA_REQUIRE_CUDA "cuda>=10.0 brand=tesla,driver>=384,driver<385 brand=tesla,driver>=410,driver<411"

ENV CUDA_HOME /usr/local/cuda

## FROM CUDA 10.0 runtime

ENV NCCL_VERSION 2.4.2

RUN apt-get update && apt-get install -y --no-install-recommends \
        cuda-libraries-$CUDA_PKG_VERSION \
        cuda-nvtx-$CUDA_PKG_VERSION \
        libnccl2=$NCCL_VERSION-1+cuda10.0 && \
    apt-mark hold libnccl2 && \
    rm -rf /var/lib/apt/lists/*


## FROM CUDA 10.0 devel

RUN apt-get update && apt-get install -y --no-install-recommends \
        cuda-libraries-dev-$CUDA_PKG_VERSION \
        cuda-nvml-dev-$CUDA_PKG_VERSION \
        cuda-minimal-build-$CUDA_PKG_VERSION \
        cuda-command-line-tools-$CUDA_PKG_VERSION \
        libnccl-dev=$NCCL_VERSION-1+cuda10.0 && \
    rm -rf /var/lib/apt/lists/*

ENV LIBRARY_PATH /usr/local/cuda/lib64/stubs

## FROM CUDA 10.0-CUDNN 7 devel

ENV CUDNN_VERSION 7.6.0.64
LABEL com.nvidia.cudnn.version="${CUDNN_VERSION}"

RUN apt-get update && apt-get install -y --no-install-recommends \
            libcudnn7=$CUDNN_VERSION-1+cuda10.0 \
            libcudnn7-dev=$CUDNN_VERSION-1+cuda10.0 && \
    apt-mark hold libcudnn7 

RUN ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime

RUN apt-get -q update

RUN apt-get install -y apt-utils tzdata

RUN dpkg-reconfigure --frontend noninteractive tzdata

RUN apt-get install -y python python3 python-pip python3-pip python-dev libpython-dev python3-dev libpython3-dev \
    python-numpy python-scipy python-pil python3-numpy python3-scipy python3-pil libcurl4-openssl-dev libssl-dev \
    python-cairo libcairo2-dev libgirepository1.0-dev python3-pycurl git-core wget build-essential \
    ca-certificates git ipython ipython3 libprotobuf-dev libleveldb-dev libsnappy-dev libopencv-dev \
    libhdf5-serial-dev libboost-all-dev libatlas-base-dev libgflags-dev libgoogle-glog-dev liblmdb-dev \
    protobuf-compiler software-properties-common libboost-dev libboost-all-dev libhdf5-100 libhdf5-serial-dev \
    libhdf5-dev libhdf5-cpp-100 lbzip2 libfftw3-dev libgdal-dev libgeos-dev libgsl0-dev libgl1-mesa-dev \
    libglu1-mesa-dev libhdf4-alt-dev libhdf5-dev libjq-dev liblwgeom-dev libpq-dev libproj-dev libprotobuf-dev \
    libnetcdf-dev libsqlite3-dev libssl-dev libudunits2-dev netcdf-bin postgis protobuf-compiler sqlite3 \
    tk-dev unixodbc-dev python-jsonschema

RUN pip install -U pip

RUN pip install python-dateutil --upgrade

RUN pip3 install python-dateutil --upgrade

RUN pip3 install --upgrade tensorflow-gpu tensorboard

RUN pip3 install gpt-2-simple

RUN add-apt-repository ppa:mc3man/bionic-media -y && \
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
  pip3 install pyyaml

RUN ldconfig

RUN mkdir /deepdream
WORKDIR /deepdream

# Download and compile Caffe
RUN git clone https://github.com/nerdymark/caffe.git
RUN cd caffe && \
  cp Makefile.config.example Makefile.config && echo "CPU_ONLY := 0" >> Makefile.config && \
  make all -j4 

RUN cd caffe && \
  pip3 install --requirement python/requirements.txt 
RUN cd caffe && make pycaffe -j2
RUN cd caffe && make distribute

RUN apt-get install -y caffe-cuda  python3-caffe-cuda caffe-tools-cuda

RUN pip install pyyaml
RUN cd caffe/scripts && ./download_model_binary.py ../models/bvlc_googlenet/

RUN pip3 install protobuf && pip3 install tornado --upgrade

RUN git clone https://github.com/google/deepdream

# Uncomment to include DeepDream Video
WORKDIR /deepdream/deepdream
RUN git clone https://github.com/graphific/DeepDreamVideo
RUN cd DeepDreamVideo && chmod a+x *.py

#ENV LD_LIBRARY_PATH=/deepdream/caffe/distribute/lib
#ENV PYTHONPATH=/deepdream/caffe/distribute/python

EXPOSE 8888

WORKDIR /deepdream
ADD start.sh start.sh

ADD GifMaker.ipynb /deepdream/deepdream/GifMaker.ipynb
ADD Untitled.ipynb /deepdream/deepdream/Untitled.ipynb
ADD Untitled12.ipynb /deepdream/deepdream/Untitled12.ipynb
ADD Untitled13.ipynb /deepdream/deepdream/Untitled13.ipynb
ADD Untitled2.ipynb /deepdream/deepdream/Untitled2.ipynb
ADD Untitled3.ipynb /deepdream/deepdream/Untitled3.ipynb
ADD Untitled4.ipynb /deepdream/deepdream/Untitled4.ipynb
ADD Untitled6.ipynb /deepdream/deepdream/Untitled6.ipynb
ADD Untitled9.ipynb /deepdream/deepdream/Untitled9.ipynb
ADD artGen.ipynb /deepdream/deepdream/artGen.ipynb


RUN mkdir ~/.jupyter

RUN echo "c.NotebookApp.ip = '0.0.0.0'" >> ~/.jupyter/jupyter_notebook_config.py

RUN mkdir /deepdream/deepdream/gpt-2
WORKDIR /deepdream/deepdream/gpt-2
ADD src /deepdream/deepdream/gpt-2/src
ADD download_model.py /deepdream/deepdream/gpt-2
ADD domains.txt /deepdream/deepdream/gpt-2
ADD model_card.md /deepdream/deepdream/gpt-2


RUN python3 download_model.py 124M
RUN python3 download_model.py 355M
RUN python3 download_model.py 774M
RUN python3 download_model.py 1558M

RUN pip3 install jupyter --upgrade
RUN pip3 install jupyter-console --upgrade

#RUN ipython kernelspec install-self
RUN ipython3 kernelspec install-self

#RUN apt-get clean

WORKDIR /deepdream/deepdream

RUN git clone https://github.com/kylemcdonald/gpt-2-poetry.git

RUN git clone https://github.com/kylemcdonald/python-utils.git

RUN git clone https://github.com/bestkao/face_gen.git

RUN git clone https://github.com/gsurma/face_generator.git

RUN git clone https://github.com/silky/cppn-3d.git

WORKDIR /deepdream

ADD download-urls.py /deepdream/deepdream/gpt-2-poetry
ADD Untitled.ipynb /deepdream/deepdream
#ADD realdonaldtrump.json /deepdream/deepdream/gpt-2/src
ADD Presidential.ipynb /deepdream/deepdream/gpt-2/src

RUN pip3 install scikit-image==0.14.2
RUN pip3 install numpy==1.15

CMD ["./start.sh"]

#!/bin/bash

BRANCH=v2.16.1
VERSION=2.16.1-3
PLATFORM=${1:-x86_64}

apt-get update
apt-get install -y --no-install-recommends \
	ca-certificates curl build-essential clang fakeroot chrpath \
	dh-exec devscripts git python3 python3-numpy libegl1-mesa-dev libgles2-mesa-dev

# make sure python3 is available to bazel
ln -s /usr/bin/python3 /usr/bin/python

git clone https://github.com/tensorflow/tensorflow.git --depth 1 --branch $BRANCH

# install the appropriate version of bazel
read -r BAZEL < tensorflow/.bazelversion
curl -L https://github.com/bazelbuild/bazel/releases/download/${BAZEL}/bazel-${BAZEL}-linux-$PLATFORM > /usr/bin/bazel
chmod +x /usr/bin/bazel


# hacked in for building >= v2.13.0 to dynamically load the system install library (and not rely on the dev package being installed)
sed -i 's/\+ nativewindow_linkopts()//' tensorflow/tensorflow/lite/delegates/gpu/build_defs.bzl
sed -i 's/"libOpenCL.so"/"libOpenCL.so.1"/' tensorflow/tensorflow/lite/delegates/gpu/cl/opencl_wrapper.cc

pushd tensorflow
bazel build --jobs 8 -c opt --copt -DTFLITE_ENABLE_GPU=ON --copt -DTFLITE_ENABLE_XNNPACK=ON --linkopt -Wl,-soname,libtensorflowlite_c.so.2 //tensorflow/lite/c:tensorflowlite_c
bazel build --jobs 8 -c opt --copt -DTFLITE_GPU_BINARY_RELEASE --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 --linkopt -Wl,-soname,libtensorflowlite_gpu_delegate.so.2 //tensorflow/lite/delegates/gpu:libtensorflowlite_gpu_delegate.so

# build the debian package
cp -r ../debian .
dch --distribution=unstable -Mv "$VERSION" "New upstream release"
dpkg-buildpackage -b -uc -us
popd

# image:
# 	ARG DISTRIBUTION=jammy
# 	FROM +$DISTRIBUTION
# 	ENV DEBIAN_FRONTEND noninteractive
# 	ENV DEBCONF_NONINTERACTIVE_SEEN true
# 	WORKDIR /code

# 	RUN apt-get update \
# 		&& apt-get install -y --no-install-recommends ca-certificates curl build-essential clang fakeroot chrpath dh-exec devscripts


# build:
# 	FROM +image

# 	RUN apt-get update \
# 		&& apt-get install -y --no-install-recommends git python3 python3-numpy libegl1-mesa-dev libgles2-mesa-dev \
# 		&& ln -s /usr/bin/python3 /usr/bin/python

# 	ARG BRANCH=v2.16.1
# 	RUN git clone https://github.com/tensorflow/tensorflow.git --depth 1 --branch $BRANCH

# 	ARG TARGETARCH
# 	LET target=x86_64
# 	IF [ "$TARGETARCH" = "arm64" ]
# 		SET target=arm64
# 	END

# 	# install the specific version of bazel required
# 	RUN read -r BAZEL < tensorflow/.bazelversion  \
# 		&& curl -L https://github.com/bazelbuild/bazel/releases/download/${BAZEL}/bazel-${BAZEL}-linux-$target > /usr/bin/bazel \
#  		&& chmod +x /usr/bin/bazel

# 	# hacked in for building >= v2.13.0
# 	RUN sed -i 's/\+ nativewindow_linkopts()//' tensorflow/tensorflow/lite/delegates/gpu/build_defs.bzl \
# 		&& sed -i 's/"libOpenCL.so"/"libOpenCL.so.1"/' tensorflow/tensorflow/lite/delegates/gpu/cl/opencl_wrapper.cc

# 	RUN cd tensorflow \
# 		&& bazel build --jobs 8 -c opt --copt -DTFLITE_ENABLE_GPU=ON --copt -DTFLITE_ENABLE_XNNPACK=ON --linkopt -Wl,-soname,libtensorflowlite_c.so.2 //tensorflow/lite/c:tensorflowlite_c  \
# 		&& bazel build --jobs 8 -c opt --copt -DTFLITE_GPU_BINARY_RELEASE --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 --linkopt -Wl,-soname,libtensorflowlite_gpu_delegate.so.2 //tensorflow/lite/delegates/gpu:libtensorflowlite_gpu_delegate.so


# package:
# 	FROM +build

# 	ARG VERSION=2.16.1-2
# 	COPY --dir debian ./tensorflow
# 	RUN cd tensorflow \
# 		&& dch --distribution=unstable -Mv "$VERSION" "New upstream release" \
# 		&& dpkg-buildpackage -b -uc -us

# 	ARG DISTRIBUTION=bionic
# 	SAVE ARTIFACT *.deb AS LOCAL build/$DISTRIBUTION/

# all-dists:
# 	BUILD +package --DISTRIBUTION=jammy --DISTRIBUTION=noble

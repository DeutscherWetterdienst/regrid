# Slim Docker multi-stage build
# for Magics

# Build image
ARG PYTHON_VERSION=3.7.7
ARG ECCODES_VERSION=2.17.1
FROM deutscherwetterdienst/python-eccodes:${PYTHON_VERSION}-${ECCODES_VERSION}-latest as build

RUN set -ex \
    && apt-get update \
    && apt-get install --yes --no-install-suggests --no-install-recommends \
      bison \
      bzip2 \
      ca-certificates \
      cmake \
      curl \
      wget \
      file \
      flex \
      g++-8 \
      gcc-8 \
      gfortran-8 \
      git \
      make \
      patch \
      sudo \
      swig \
      xz-utils

RUN set -ex \
    && ln -s /usr/bin/g++-8 /usr/bin/g++ \
    && ln -s /usr/bin/gcc-8 /usr/bin/gcc \
    && ln -s /usr/bin/gfortran-8 /usr/bin/gfortran

# Install Climate Data Operator (CDO) with NetCDF, GRIB2 and HDF5 support
# see https://code.mpimet.mpg.de/projects/cdo/embedded/index.html#x1-30001.1
# see http://www.studytrails.com/blog/install-climate-data-operator-cdo-with-netcdf-grib2-and-hdf5-support/

# Install build-time dependencies for NetCDF, HDF5 and CDO
RUN set -ex \
    && apt-get install --yes --no-install-suggests --no-install-recommends \
      libcurl4-gnutls-dev

# Install ZLIB from source
# ZLIB source from https://zlib.net
ARG ZLIB_VERSION=1.2.11
RUN set -ex \
    && mkdir -p /src \
    && cd /src \
    && echo "Installing zlib version ${ZLIB_VERSION} ..." \
    && wget https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz \
    && tar -xzvf zlib-${ZLIB_VERSION}.tar.gz \
    && cd zlib-${ZLIB_VERSION} \
    && ./configure --prefix /usr/local \
    && make && make check && make install \
    && /sbin/ldconfig

# Install HDF5 from source
# HDF5 source from https://github.com/live-clones/hdf5
ARG HDF5_VERSION=hdf5-1_12_0
RUN set -ex \
    && mkdir -p /src \
    && cd /src \
    && echo "Installing HDF5 version ${HDF5_VERSION} ..." \
    && git clone https://github.com/live-clones/hdf5.git && cd hdf5 && git checkout ${HDF5_VERSION} \
    && ./configure \
        --prefix /usr/local \
        --with-zlib=/usr/local \
        --enable-threadsafe \
        --enable-unsupported \
          CFLAGS=-fPIC \
    && make && make check && make install \
    && /sbin/ldconfig

# Install NetCDF from source
# NetCDF source from http://www.unidata.ucar.edu/downloads/netcdf/index.jsp
ARG NETCDF_VERSION=4.7.4
RUN set -ex \
    && mkdir -p /src \
    && cd /src \
    && echo "Installing NetCDF version ${NETCDF_VERSION} ..." \
    && wget https://www.unidata.ucar.edu/downloads/netcdf/ftp/netcdf-c-${NETCDF_VERSION}.tar.gz \
    && tar -xf netcdf-c-${NETCDF_VERSION}.tar.gz \
    && cd netcdf-c-${NETCDF_VERSION} \
    && CPPFLAGS=-I/usr/local/include LDFLAGS=-L/usr/local/lib \
    && ./configure \
        --prefix /usr/local \
        --with-hdf5=/usr/local \
        --with-zlib=/usr/local \
        --enable-netcdf-4 \
          CFLAGS=-fPIC \
    && make && make check && make install \
    && /sbin/ldconfig

# Install JasPer from source
# JasPer source from https://github.com/mdadams/jasper
ARG JASPER_VERSION=version-2.0.16
ARG JASPER_SOURCE_DIR=./
ARG JASPER_BUILD_DIR=/src/jasper/release
ARG JASPER_INSTALL_DIR=/usr/local
RUN set -ex \
    && mkdir -p /src \
    && cd /src \
    && echo "Installing JasPer version ${JASPER_VERSION} ..." \
    && git clone https://github.com/mdadams/jasper.git && cd jasper && git checkout ${JASPER_VERSION} \
    && mkdir -p ${JASPER_BUILD_DIR} \
    && cmake -G "Unix Makefiles" \
        -H${JASPER_SOURCE_DIR} \
        -B${JASPER_BUILD_DIR} \
        -DCMAKE_INSTALL_PREFIX=${JASPER_INSTALL_DIR} \
        -DCMAKE_BUILD_TYPE=Release \
    && cd release \
    && make clean all && make install \
    && /sbin/ldconfig

# Install CDO
# CDO source code from https://code.mpimet.mpg.de/projects/cdo/files
ARG CDO_VERSION=1.9.8
RUN set -ex \
    && mkdir -p /src \
    && cd /src \
    && echo "Installing CDO version ${CDO_VERSION} ..." \
    && wget https://code.mpimet.mpg.de/attachments/download/20826/cdo-${CDO_VERSION}.tar.gz \
    && tar -xf cdo-${CDO_VERSION}.tar.gz \
    && cd cdo-${CDO_VERSION} \
    && ./configure --prefix /usr/local CFLAGS=-fPIC  \
            --with-netcdf=/usr/local \
            --with-jasper=/usr/local \
            --with-hdf5=/usr/local \
            --with-eccodes=/usr/local \
    && make && make check && make install \
    && /sbin/ldconfig

# Remove unneeded files.
RUN set -ex \
    && find /usr/local -name 'lib*.so' | xargs -r -- strip --strip-unneeded || true \
    && find /usr/local/bin | xargs -r -- strip --strip-all || true \
    && find /usr/local/lib -name __pycache__ | xargs -r -- rm -rf

#
# Minimal run-time image.
#
FROM debian:stable-slim as minimal

# Install run-time dependencies
RUN set -ex \
    && apt-get update \
    && apt-get install --yes --no-install-suggests --no-install-recommends \
      libcurl4-gnutls-dev \
      libopenjp2-7 \
      libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy CDO and associated libraries
COPY --from=build /usr/local/share/eccodes /usr/local/share/eccodes
COPY --from=build /usr/local/bin/ /usr/local/bin/
COPY --from=build /usr/local/lib/ /usr/local/lib/
# header files
COPY --from=build /usr/local/include/ /usr/local/include/
# eccodes-python
COPY --from=build /src/eccodes-python/ /src/eccodes-python/

# Ensure shared libs installed by the previous step are available.
RUN set -ex \
    && /sbin/ldconfig

# Default command
ENV MODEL=undefined-model-env
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/${MODEL}_output.grib2
CMD cdo -f grb2 remap,${DESCRIPTION_FILE},${WEIGHTS_FILE} ${INPUT_FILE} ${OUTPUT_FILE}

# METADATA
# Build-time metadata as defined at http://label-schema.org
# --build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
ARG BUILD_DATE
# --build-arg VCS_REF=`git rev-parse --short HEAD`, e.g. 'c30d602'
ARG VCS_REF
# --build-arg VCS_URL=`git config --get remote.origin.url`, e.g. 'https://github.com/deutscherwetterdienst/python-eccodes'
ARG VCS_URL
# --build-arg VERSION=`git tag`, e.g. '0.2.1'
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
        org.label-schema.name="DWD NWP Regrid" \
        org.label-schema.description="A collection of tools to regrid DWD's NWP model data." \
        org.label-schema.url="https://www.dwd.de/opendatahelp" \
        org.label-schema.vcs-ref=$VCS_REF \
        org.label-schema.vcs-url=$VCS_URL \
        org.label-schema.vendor="DWD - Deutscher Wetterdienst" \
        org.label-schema.version=$VERSION \
        org.label-schema.schema-version="1.0"

################################
# Model: ICON-D2
################################
# Intermediate image with additional tools
FROM minimal as icon-d2-intermediate

# Install run-time dependencies
RUN set -ex \
    && apt-get update \
    && apt-get install --yes --no-install-suggests --no-install-recommends \
      bzip2 \
      ca-certificates \
      curl \
      wget \
    && rm -rf /var/lib/apt/lists/*

ARG MODEL_NAME=icon-d2

# copy samples and descriptions
COPY /data/samples/${MODEL_NAME} /data/samples/${MODEL_NAME}
COPY /data/descriptions/${MODEL_NAME} /data/descriptions/${MODEL_NAME}

# # download grid definition and generate weights
# ARG GRID_FILENAME=/icon_grid_0044_R19B07_L.nc.bz2
# RUN set -ex \
#     && mkdir -p /data/grids/${MODEL_NAME} \
#     && cd /data/grids/${MODEL_NAME} \
#     && wget -O ${MODEL_NAME}_grid.nc.bz2 https://opendata.dwd.de/weather/lib/cdo/${GRID_FILENAME} \
#     && bunzip2 ${MODEL_NAME}_grid.nc.bz2 \
#     && mkdir -p /data/weights/${MODEL_NAME} \
#     && cd /data/weights/${MODEL_NAME} \
#     && echo Generating weights for ${MODEL_NAME} ... \
#     && cdo \
#          gennn,/data/descriptions/${MODEL_NAME}/${MODEL_NAME}_description.txt \
#          /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc \
#          /data/weights/${MODEL_NAME}/${MODEL_NAME}_weights.nc

# download grid definition and generate weights
COPY /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc
# workaround for incomplete grid file: needs a copy/symbolic link named 'private'
RUN set -ex \
    && ln -s /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc /data/grids/${MODEL_NAME}/private \
    && mkdir -p /data/weights/${MODEL_NAME} \
    && cd /data/weights/${MODEL_NAME} \
    && echo $(ls -la /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc) \
    && echo Generating weights for ${MODEL_NAME} ... \
    && cdo \
         gennn,/data/descriptions/${MODEL_NAME}/${MODEL_NAME}_description.txt \
         /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc \
         /data/weights/${MODEL_NAME}/${MODEL_NAME}_weights.nc


## Minimal image for regridding with predefined output
FROM minimal as icon-d2
COPY --from=icon-d2-intermediate /data/descriptions /data/descriptions
COPY --from=icon-d2-intermediate /data/weights /data/weights
ENV MODEL=icon-d2
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc

## Image with weights and sample data
FROM minimal as icon-d2-samples
COPY --from=icon-d2 /data /data
COPY --from=icon-d2-intermediate /data/samples /data/samples
ENV MODEL=icon-d2
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2

## Image with grids, weights and samples
FROM minimal as icon-d2-grids
COPY --from=icon-d2-intermediate /data /data
ENV MODEL=icon-d2
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2
ENV GRID_FILE=/data/grids/${MODEL}/${MODEL}_grid.nc

################################
# Model: ICON-D2-EPS
################################
# Intermediate image with additional tools
FROM minimal as icon-d2-eps-intermediate

# Install run-time dependencies
RUN set -ex \
    && apt-get update \
    && apt-get install --yes --no-install-suggests --no-install-recommends \
      bzip2 \
      ca-certificates \
      curl \
      wget \
    && rm -rf /var/lib/apt/lists/*

ARG MODEL_NAME=icon-d2-eps

# copy samples and descriptions
COPY /data/samples/${MODEL_NAME} /data/samples/${MODEL_NAME}
COPY /data/descriptions/${MODEL_NAME} /data/descriptions/${MODEL_NAME}

# # download grid definition and generate weights
# ARG GRID_FILENAME=/icon_grid_0044_R19B07_L.nc.bz2
# RUN set -ex \
#     && mkdir -p /data/grids/${MODEL_NAME} \
#     && cd /data/grids/${MODEL_NAME} \
#     && wget -O ${MODEL_NAME}_grid.nc.bz2 https://opendata.dwd.de/weather/lib/cdo/${GRID_FILENAME} \
#     && bunzip2 ${MODEL_NAME}_grid.nc.bz2 \
#     && mkdir -p /data/weights/${MODEL_NAME} \
#     && cd /data/weights/${MODEL_NAME} \
#     && echo Generating weights for ${MODEL_NAME} ... \
#     && cdo \
#          gennn,/data/descriptions/${MODEL_NAME}/${MODEL_NAME}_description.txt \
#          /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc \
#          /data/weights/${MODEL_NAME}/${MODEL_NAME}_weights.nc

# download grid definition and generate weights
COPY /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc
# workaround for incomplete grid file: needs a copy/symbolic link named 'private'
RUN set -ex \
    && ln -s /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc /data/grids/${MODEL_NAME}/private \
    && mkdir -p /data/weights/${MODEL_NAME} \
    && cd /data/weights/${MODEL_NAME} \
    && echo Generating weights for ${MODEL_NAME} ... \
    && cdo \
         gennn,/data/descriptions/${MODEL_NAME}/${MODEL_NAME}_description.txt \
         /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc \
         /data/weights/${MODEL_NAME}/${MODEL_NAME}_weights.nc


## Minimal image for regridding with predefined output
FROM minimal as icon-d2-eps
COPY --from=icon-d2-eps-intermediate /data/descriptions /data/descriptions
COPY --from=icon-d2-eps-intermediate /data/weights /data/weights
ENV MODEL=icon-d2-eps
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc

## Image with weights and sample data
FROM minimal as icon-d2-eps-samples
COPY --from=icon-d2-eps /data /data
COPY --from=icon-d2-eps-intermediate /data/samples /data/samples
ENV MODEL=icon-d2-eps
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2

## Image with grids, weights and samples
FROM minimal as icon-d2-eps-grids
COPY --from=icon-d2-eps-intermediate /data /data
ENV MODEL=icon-d2-eps
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2
ENV GRID_FILE=/data/grids/${MODEL}/${MODEL}_grid.nc

################################
# Model: ICON-EU-EPS
################################
# Intermediate image with additional tools
FROM minimal as icon-eu-eps-intermediate

# Install run-time dependencies
RUN set -ex \
    && apt-get update \
    && apt-get install --yes --no-install-suggests --no-install-recommends \
      bzip2 \
      ca-certificates \
      curl \
      wget \
    && rm -rf /var/lib/apt/lists/*

ARG MODEL_NAME=icon-eu-eps

# copy samples and descriptions
COPY /data/samples/${MODEL_NAME} /data/samples/${MODEL_NAME}
COPY /data/descriptions/${MODEL_NAME} /data/descriptions/${MODEL_NAME}

# download grid definition and generate weights
ARG GRID_FILENAME=icon_grid_0028_R02B07_N02.nc.bz2
RUN set -ex \
    && mkdir -p /data/grids/${MODEL_NAME} \
    && cd /data/grids/${MODEL_NAME} \
    && wget -O ${MODEL_NAME}_grid.nc.bz2 https://opendata.dwd.de/weather/lib/cdo/${GRID_FILENAME} \
    && bunzip2 ${MODEL_NAME}_grid.nc.bz2 \
    && mkdir -p /data/weights/${MODEL_NAME} \
    && cd /data/weights/${MODEL_NAME} \
    && echo Generating weights for ${MODEL_NAME} ... \
    && cdo \
         gennn,/data/descriptions/${MODEL_NAME}/${MODEL_NAME}_description.txt \
         /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc \
         /data/weights/${MODEL_NAME}/${MODEL_NAME}_weights.nc


## Minimal image for regridding with predefined output
FROM minimal as icon-eu-eps
COPY --from=icon-eu-eps-intermediate /data/descriptions /data/descriptions
COPY --from=icon-eu-eps-intermediate /data/weights /data/weights
ENV MODEL=icon-eu-eps
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc

## Image with weights and sample data
FROM minimal as icon-eu-eps-samples
COPY --from=icon-eu-eps /data /data
COPY --from=icon-eu-eps-intermediate /data/samples /data/samples
ENV MODEL=icon-eu-eps
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2

## Image with grids, weights and samples
FROM minimal as icon-eu-eps-grids
COPY --from=icon-eu-eps-intermediate /data /data
ENV MODEL=icon-eu-eps
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2
ENV GRID_FILE=/data/grids/${MODEL}/${MODEL}_grid.nc

################################
# Model: ICON-EPS
################################
# Intermediate image with additional tools
FROM minimal as icon-eps-intermediate

# Install run-time dependencies
RUN set -ex \
    && apt-get update \
    && apt-get install --yes --no-install-suggests --no-install-recommends \
      bzip2 \
      ca-certificates \
      curl \
      wget \
    && rm -rf /var/lib/apt/lists/*

ARG MODEL_NAME=icon-eps

# copy samples and descriptions
COPY /data/samples/${MODEL_NAME} /data/samples/${MODEL_NAME}
COPY /data/descriptions/${MODEL_NAME} /data/descriptions/${MODEL_NAME}

# download grid definition and generate weights
ARG GRID_FILENAME=icon_grid_0024_R02B06_G.nc.bz2
RUN set -ex \
    && mkdir -p /data/grids/${MODEL_NAME} \
    && cd /data/grids/${MODEL_NAME} \
    && wget -O ${MODEL_NAME}_grid.nc.bz2 https://opendata.dwd.de/weather/lib/cdo/${GRID_FILENAME} \
    && bunzip2 ${MODEL_NAME}_grid.nc.bz2 \
    && mkdir -p /data/weights/${MODEL_NAME} \
    && cd /data/weights/${MODEL_NAME} \
    && echo Generating weights for ${MODEL_NAME} ... \
    && cdo \
         gennn,/data/descriptions/${MODEL_NAME}/${MODEL_NAME}_description.txt \
         /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc \
         /data/weights/${MODEL_NAME}/${MODEL_NAME}_weights.nc


## Minimal image for regridding with predefined output
FROM minimal as icon-eps
COPY --from=icon-eps-intermediate /data/descriptions /data/descriptions
COPY --from=icon-eps-intermediate /data/weights /data/weights
ENV MODEL=icon-eps
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc

## Image with weights and sample data
FROM minimal as icon-eps-samples
COPY --from=icon-eps /data /data
COPY --from=icon-eps-intermediate /data/samples /data/samples
ENV MODEL=icon-eps
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2

## Image with grids, weights and samples
FROM minimal as icon-eps-grids
COPY --from=icon-eps-intermediate /data /data
ENV MODEL=icon-eps
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2
ENV GRID_FILE=/data/grids/${MODEL}/${MODEL}_grid.nc

################################
# Model: ICON
################################
# Intermediate image with additional tools
FROM minimal as icon-intermediate

# Install run-time dependencies
RUN set -ex \
    && apt-get update \
    && apt-get install --yes --no-install-suggests --no-install-recommends \
      bzip2 \
      ca-certificates \
      curl \
      wget \
    && rm -rf /var/lib/apt/lists/*

ARG MODEL_NAME=icon

# copy samples and descriptions
COPY /data/samples/${MODEL_NAME} /data/samples/${MODEL_NAME}
COPY /data/descriptions/${MODEL_NAME} /data/descriptions/${MODEL_NAME}

# download grid definition and generate weights
ARG GRID_FILENAME=icon_grid_0026_R03B07_G.nc.bz2
RUN set -ex \
    && mkdir -p /data/grids/${MODEL_NAME} \
    && cd /data/grids/${MODEL_NAME} \
    && wget -O ${MODEL_NAME}_grid.nc.bz2 https://opendata.dwd.de/weather/lib/cdo/${GRID_FILENAME} \
    && bunzip2 ${MODEL_NAME}_grid.nc.bz2 \
    && mkdir -p /data/weights/${MODEL_NAME} \
    && cd /data/weights/${MODEL_NAME} \
    && echo Generating weights for ${MODEL_NAME} ... \
    && cdo \
         gennn,/data/descriptions/${MODEL_NAME}/${MODEL_NAME}_description.txt \
         /data/grids/${MODEL_NAME}/${MODEL_NAME}_grid.nc \
         /data/weights/${MODEL_NAME}/${MODEL_NAME}_weights.nc


## Minimal image for regridding with predefined output
FROM minimal as icon
COPY --from=icon-intermediate /data/descriptions /data/descriptions
COPY --from=icon-intermediate /data/weights /data/weights
ENV MODEL=icon
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc

## Image with weights and sample data
FROM minimal as icon-samples
COPY --from=icon /data /data
COPY --from=icon-intermediate /data/samples /data/samples
ENV MODEL=icon
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2

## Image with grids, weights and samples
FROM minimal as icon-grids
COPY --from=icon-intermediate /data /data
ENV MODEL=icon
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2
ENV GRID_FILE=/data/grids/${MODEL}/${MODEL}_grid.nc

################################
# Model: ALL MODELS
################################
FROM minimal as all-intermediate
COPY --from=icon-d2-grids /data /data
COPY --from=icon-d2-eps-grids /data /data
COPY --from=icon-eu-eps-grids /data /data
COPY --from=icon-eps-grids /data /data
COPY --from=icon-grids /data /data

## Minimal image for regridding with predefined output
FROM minimal as all
COPY --from=all-intermediate /data/descriptions /data/descriptions
COPY --from=all-intermediate /data/weights /data/weights
ENV MODEL=icon
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc

## Image with sample data
FROM minimal as all-samples
COPY --from=all /data /data
COPY --from=all-intermediate /data/samples /data/samples
ENV MODEL=icon
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2

## Image with grids, weights and samples
FROM minimal as all-grids
COPY --from=all-intermediate /data /data
ENV MODEL=icon
ENV DESCRIPTION_FILE=/data/descriptions/${MODEL}/${MODEL}_description.txt
ENV WEIGHTS_FILE=/data/weights/${MODEL}/${MODEL}_weights.nc
ENV INPUT_FILE=/data/samples/${MODEL}/${MODEL}_sample.grib2
ENV OUTPUT_FILE=/data/samples/${MODEL}/${MODEL}_output.grib2
ENV GRID_FILE=/data/grids/${MODEL}/${MODEL}_grid.nc
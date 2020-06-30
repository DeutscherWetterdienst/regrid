[![CDO version](https://img.shields.io/badge/CDO-1.9.8-informational)](https://code.mpimet.mpg.de/projects/cdo/files)
[![Python version](https://img.shields.io/badge/python-3.7.7-informational)](https://hub.docker.com/_/python)
[![ecCodes version](https://img.shields.io/badge/ecCodes-2.17.1-informational)](https://github.com/ecmwf/eccodes)
[![zlib version](https://img.shields.io/badge/zlib-1.2.11-informational)](https://zlib.net)
[![HDF5 version](https://img.shields.io/badge/HDF5-1.12.0-informational)](https://github.com/live-clones/hdf5)
[![NetCDF version](https://img.shields.io/badge/NetCDF-4.7.4-informational)](http://www.unidata.ucar.edu/downloads/netcdf/index.jsp)
[![JasPer version](https://img.shields.io/badge/JasPer-2.0.16-informational)](https://github.com/mdadams/jasper)
[![Docker Build Status](https://img.shields.io/docker/cloud/build/deutscherwetterdienst/regrid.svg)](https://hub.docker.com/r/deutscherwetterdienst/regrid)
[![Docker Pulls](https://img.shields.io/docker/pulls/deutscherwetterdienst/regrid)](https://hub.docker.com/r/deutscherwetterdienst/regrid)

# Regrid DWD ICON Data
A collection of tools and configurations that allow you to interpolate/regrid [DWD's NWP ICON model data](https://www.dwd.de/EN/ourservices/nwp_forecast_data/nwp_forecast_data.html) from icosahedral(triangular) ICON grids onto regular latitude-longitude (geographical) grids using [MPIMET CDO](https://code.mpimet.mpg.de/projects/cdo/files) and [ECMWF ecCodes](https://github.com/ecmwf/eccodes). DWD's NWP data is [freely available](https://www.dwd.de/EN/ourservices/opendata/opendata.html) for download from DWD's Open Data File Server at https://opendata.dwd.de/weather/nwp/ . 

## Table of Contents
- [Available images](#available-images)
  * [Model specific images](#model-specific-images)
  * [Docker Tags](#docker-tags)
    + [``<model>``](#---model---)
    + [``-samples``](#---samples--)
    + [``-grids``](#---grids--)
    + [``<version>|-<version>``](#---version----version---)
  * [Images for advanced users](#images-for-advanced-users)
- [Usage](#usage)
  * [Get Version Information](#get-version-information)
  * [Basic interpolation](#basic-interpolation)
    + [Regrid sample files](#regrid-sample-files)
    + [Regrid custom files](#regrid-custom-files)
    + [Example 1: Regrid a single file from you local hard drive](#example-1--regrid-a-single-file-from-you-local-hard-drive)
    + [Example 2: Interpolate all files from a local folder](#example-2--interpolate-all-files-from-a-local-folder)
  * [Interactive usage](#interactive-usage)
    + [Interactive shell](#interactive-shell)
    + [Analyse input](#analyse-input)
    + [Interpolate from triangular to regular-lat-lon grid](#interpolate-from-triangular-to-regular-lat-lon-grid)
    + [Analyse output](#analyse-output)
  * [Custom regridding](#custom-regridding)
    + [Environment Variables](#environment-variables)
    + [Custom grid descriptions and weights](#custom-grid-descriptions-and-weights)
    + [Example 1: Create a CDO grid description file](#example-1--create-a-cdo-grid-description-file)
    + [Example 2: Generate weights and regrid](#example-2--generate-weights-and-regrid)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>




# Available images
There are a variety of different docker images available for different regridding tasks.

## Model specific images
Docker images that are tagged with a model name such as ``icon-eu-eps`` or ``all`` provide all necessary files to regrid data from these models. Currently the following models are supported:
 * ICON Global: ``deutscherwetterdienst/regrid:icon``
 * ICON Global Ensemble: ``deutscherwetterdienst/regrid:icon-eps``
 * ICON EU Nest Ensemble: ``deutscherwetterdienst/regrid:icon-eu-eps``
 * ICON-D2 (pre-operational): ``deutscherwetterdienst/regrid:icon-eu-eps``
 * ICON-D2 Ensemble (pre-operational): ``deutscherwetterdienst/regrid:icon-eu-eps``

## Docker Tags
The general nomenclature for tags is as follows: 
```
deutscherwetterdienst/regrid:[<model>|all][-samples|-grids][<version>|-<version>]
```

### ``<model>``
These images contain precomputed interpolation weights located in ``/data/weights/`` for remapping model data to a regular-lat-lon/geographical grid at full resolution, e.g.:
 * ICON EU Nest Ensemble: ``deutscherwetterdienst/regrid:icon-eu-eps``
 * all supported models: ``deutscherwetterdienst/regrid:all``
### ``-samples``
These images contain GRIB2 samples files for the given models e.g. 
 * image with sample data for all models: ``deutscherwetterdienst/regrid:all-samples``
 * image with ICON global samples: ``deutscherwetterdienst/regrid:icon-samples``
Samples are located in ``/data/samples/``.
### ``-grids``
These images contain NetCDF grid definition files. These files are necessary to create customized interpolations for the given model and are located in ``/data/grids/``. Sample files are also included in ``/data/samples/`` to simplify tests. Examples:
 * image with definition and sample files for all models: ``deutscherwetterdienst/regrid:all-grids``
  * image with definition and sample files for icon model: ``deutscherwetterdienst/regrid:icon-grids``
### ``<version>|-<version>``
Images tagged with a version suffix correspond to a specific version tag in the VCS and are considered immutable. Images without a version tag signify the latest available versions.

## Images for advanced users
We provide a slim/minimal image that contain all precompiled tools such as [ecCodes](https://github.com/ecmwf/eccodes) and [CDO](https://code.mpimet.mpg.de/projects/cdo/files), which are required to regrid/interpolate ``GRIB2`` and ``NetCDF`` files:
```
deutscherwetterdienst/regrid
```
**These images are intended for advanced users with existing knowledge of CDO**. They do not provide any model specific configurations or data and hence can not be used to regrid data without providing additional data and configurations.

# Usage
You can use the provided images interpolate data onto predefined grids or fully customize all details of the interpolation.

## Get Version Information
You can output versions the CDO version and the versions of all libraries by running:
```
docker run --rm deutscherwetterdienst/regrid cdo --version
```
The result should look like this:
```
Climate Data Operators version 1.9.8 (https://mpimet.mpg.de/cdo)
System: x86_64-pc-linux-gnu
CXX Compiler: g++ -g -O2 -fopenmp 
CXX version : g++ (Debian 8.3.0-6) 8.3.0
C Compiler: gcc -fPIC -fopenmp  
C version : gcc (Debian 8.3.0-6) 8.3.0
F77 Compiler: gfortran -g -O2
F77 version : GNU Fortran (Debian 8.3.0-6) 8.3.0
Features: 1GB 4threads C++14 Fortran DATA PTHREADS OpenMP HDF5 NC4/HDF5/threadsafe OPeNDAP SSE2
Libraries: HDF5/1.12.0
Filetypes: srv ext ieg grb1 grb2 nc1 nc2 nc4 nc4c nc5 
     CDI library version : 1.9.8
 cgribex library version : 1.9.4
 ecCodes library version : 2.17.1
  NetCDF library version : 4.7.4 of Jun 23 2020 18:51:27 $
    hdf5 library version : 1.12.0 threadsafe
    exse library version : 1.4.1
    FILE library version : 1.8.3
```

## Basic interpolation
We provide tailor made images for our models that allow you to directly interpolate all available data from icosahedral/triangular ICON grids to regular-latitude-longitude/geographical grids with maximum resolution.


### Regrid sample files
You can use images tagged with ``-samples`` to test interpolation on sample files. Run:
```
docker run --rm deutscherwetterdienst/regrid:icon-eu-eps-samples
```
This will convert the sample file, save the result in ``/data/samples/icon/icon_output.grib2`` and exit. The output should look like this:
```
cdo    remap: Processed 40 variables over 1 timestep [0.32s 79MB].
```

### Regrid custom files
You can customize which data should be interpolated and where the result should be written by overriding the following environment variables in the docker image using the ``--env <VARIABLE>=<VALUE>`` option of docker.
 * ``INPUT_FILE``: Absolute file path to the input file in GRIB2 format that needs to be transformed, e.g. ``/data/samples/icon/icon_sample.grib2``
 * ``OUTPUT_FILE``: Absulute path where the result should be written, e.g.: ``/data/samples/icon/icon_output.grib2``

### Example 1: Regrid a single file from you local hard drive
You need to mount a folder from you local hard drive and specify which file to regrid and where to save the output by setting the environment variables accordingly:
```
docker run --rm \
    --volume ~/mydata:/mydata \
    --env INPUT_FILE=/mydata/my_icon-eps_icosahedral_file.grib2 \
    --env OUTPUT_FILE=/mydata/regridded_regular_lat_lon_output.grib2 \
    deutscherwetterdienst/regrid:icon-eps
```
The output should look something like this:
```
cdo    remap: Processed 40 variables over 1 timestep [0.32s 79MB].
```
**Attention**: The model of the docker image and the grid of the selected file have match!

### Example 2: Interpolate all files from a local folder
1) Place all GRIB2 files that need to converted in a single folder, e.g ``~/mydata``. 
2) Place the a simple shell script ``convert.sh`` in the same folder as the GRIB2 data, with the following contents:
```
#!/bin/bash
# file name: convert.sh
for i in $(ls | grep -v .sh); do 
    cdo -f grb2 remap,${DESCRIPTION_FILE},${WEIGHTS_FILE} ${i} regridded_${i};
done
```
Now the contents of you folder should look something like this:
```
eduard@Eduards-Macbook-Air mydata % ls -la
total 23064
drwxr-xr-x    5 eduard  staff      160 Jun 23 22:03 .
drwxr-xr-x@ 125 eduard  staff     4000 Jun 23 21:58 ..
-rw-r--r--    1 eduard  staff      154 Jun 23 21:56 convert.sh
-rw-r--r--@   1 eduard  staff  5898409 Jun 23 21:56 icon_global_icosahedral_single-level_2020060900_000_T_2M.grib2
-rw-r--r--@   1 eduard  staff  5898409 Jun 23 21:56 icon_global_icosahedral_single-level_2020061800_000_T_2M.grib2
...
```
3. Mount the folder inside your container and run the ``convert.sh`` script:
```
docker run --rm \
    --volume ~/mydata:/mydata \
    --workdir /mydata \
    deutscherwetterdienst/regrid:icon \
    sh convert.sh
```
The output should look something like this:
```
cdo    remap: Processed 1 variable over 1 timestep [0.76s 427MB].
cdo    remap: Processed 1 variable over 1 timestep [0.74s 427MB].
...
```
Your folder should now contain the regridded files:
```
eduard@Eduards-Macbook-Air mydata % ls -la
total 56344
drwxr-xr-x    7 eduard  staff      224 Jun 23 22:10 .
drwxr-xr-x@ 125 eduard  staff     4000 Jun 23 21:58 ..
-rw-r--r--    1 eduard  staff      154 Jun 23 21:56 convert.sh
-rw-r--r--@   1 eduard  staff  5898409 Jun 23 21:56 icon_global_icosahedral_single-level_2020060900_000_T_2M.grib2
-rw-r--r--@   1 eduard  staff  5898409 Jun 23 21:56 icon_global_icosahedral_single-level_2020061800_000_T_2M.grib2
-rw-r--r--    1 eduard  staff  8297484 Jun 23 22:11 regridded_icon_global_icosahedral_single-level_2020060900_000_T_2M.grib2
-rw-r--r--    1 eduard  staff  8297484 Jun 23 22:11 regridded_icon_global_icosahedral_single-level_2020061800_000_T_2M.grib2
...
```

## Interactive usage
You can use all images by running command direcrly inside the container using an interactive shell.

### Interactive shell
Run:
```
docker run --rm -it \
    deutscherwetterdienst/regrid:icon-samples \
    bash
```
### Analyse input
Analyse the input file by running:
```
grib_ls /data/samples/icon/icon_sample.grib2
```
The output should look something like this:
```
/data/samples/icon/icon_sample.grib2
edition      centre       date         dataType     gridType     stepRange    typeOfLevel  level        shortName    packingType  
2            edzw         20200618     fc           unstructured_grid  0            heightAboveGround  2            2t           grid_simple 
1 of 1 messages in /data/samples/icon/icon_sample.grib2

1 of 1 total messages in 1 files
```

### Interpolate from triangular to regular-lat-lon grid
Run:
```
cdo -f grb2 remap,/data/descriptions/icon/icon_description.txt,/data/weights/icon/icon_weights.nc /data/samples/icon/icon_sample.grib2 /data/samples/icon/icon_regridded_output.grib2
```
### Analyse output
To analyse the output file run:
```
grib_ls /data/samples/icon/icon_regridded_output.grib2
```
The result should look something like this:
```
/data/samples/icon/icon_regridded_output.grib2
edition      centre       date         dataType     gridType     stepRange    typeOfLevel  level        shortName    packingType  
2            edzw         20200618     fc           regular_ll   0            heightAboveGround  2            2t           grid_simple 
1 of 1 messages in /data/samples/icon/icon_regridded_output.grib2

1 of 1 total messages in 1 files
```
The ``gridType`` changed from ``unstructured_grid`` (ICON triangular grid) to ``regular_ll`` (geographical grid).

## Custom regridding
You can fully customize which and how data will be interpolated by modifying environment variables and providing custom grid description files and weights files.

### Environment Variables
The following environment variables are supported:
 * ``INPUT_FILE``: Absolute file path to the input file in GRIB2 format that needs to be transformed, e.g. ``/data/samples/icon/icon_sample.grib2``
 * ``OUTPUT_FILE``: Absulute path where the result should be written, e.g. ``/data/samples/icon/icon_output.grib2``
 * ``DESCRIPTION_FILE``: The [CDO grid description file](https://code.mpimet.mpg.de/projects/cdo/embedded/index.html#x1-150001.3.2), e.g. ``/data/descriptions/icon/icon_description.txt``
 * ``WEIGHTS_FILE``: pre-computed interpolation weights - see DWD's [CDO How-To-Guide](https://www.dwd.de/DE/leistungen/opendata/help/modelle/Opendata_cdo_EN.pdf?__blob=publicationFile&v=3), e.g. ``/data/weights/icon/icon_weights.nc``
 * ``GRID_FILE``: NetCDF grid definition file, e.g. ``/data/grids/icon/icon_grid.nc``

### Custom grid descriptions and weights
You can fully customize how to regrid DWD grib data by first creating a CDO grid description file and then genrating the interpolation weights. It is possible to extract an arbitrary subset of the available data and/or interpolate the data onto a custom grid.


### Example 1: Create a CDO grid description file
First you need to create a custom (CDO grid description file)[https://code.mpimet.mpg.de/projects/cdo/embedded/index.html#x1-150001.3.2]. This file defines the grid type, the area and the resolution of the desired grib file after interpolation. The file below is an example of a cutout over Europe in a regular latitude-longitude (geographical) grid with a resolution of 0.25° x 0.25° degrees:
```
# File: output_grid.txt
# Climate Data Operator (CDO) grid description file
# Input: ICON (Global)
# Area: Europe
# Grid: regular latitude longitude/geographical grid
# Resolution: 0.25 x 0.25 degrees

gridtype  = lonlat
xsize     = 601
ysize     = 301
xfirst    = -75.0
xinc      = 0.25
yfirst    = 5.0
yinc      = 0.25
```
Save this file to a local folder, e.g. to ``~/mydata/custom_grid.txt``.

### Example 2: Generate weights and regrid
In order to generate weights, you need the grid definition files (in NetCDF) that are necessary to generate custom interpolation weights for the icon model you want to interpolate. To do this we will use the corresponding ``grids`` images. In this example we will use the ICON Global image tagged ``icon-grids``, which we will run interactively:
```
docker run --rm -it \
    --volume ~/mydata:/mydata \
    --workdir /mydata \
    deutscherwetterdienst/regrid:icon-grids \
    bash
```
Now, to precompute the weights for the custom grid definition run the following command inside the container:
```
cdo gennn,/mydata/custom_grid.txt \
    /data/grids/icon/icon_grid.nc \
    /mydata/custom_weights.nc
```
The output should look something like this:
```
cdo    gennn: Nearest neighbor weights from unstructured (2949120) to lonlat (601x301) grid
cdo    gennn: Processed 6 variables over 1 timestep [22.84s 932MB].
```
Now you can use the newly generated custom weights file ``custom_weights.nc`` to regrid the icon sample file:
```
cdo -f grb2 remap,/mydata/custom_grid.txt,/mydata/custom_weights.nc /data/samples/icon/icon_sample.grib2 /mydata/icon_custom.grib2
```
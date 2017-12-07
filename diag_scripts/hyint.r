# #############################################################################
# hyint.r
# Authors:       E. Arnone (ISAC-CNR, Italy)
#                J. von Hardenberg (ISAC-CNR, Italy) 
# #############################################################################
# Description
# HyInt is a tool for calculation of the HY-INT index (Giorgi et al. 2011) 
# and additional hydroclimatic indices (Giorgi et al. 2014)
# which allow an estimate of the overall behaviour of the hydroclimatic cycle. 
# The tool calculates also timeseries and trends over selected regions and 
# produces a variety of types of plots including maps and timeseries. The timeseries/trend
# and plotting modules handle also ETCCDI indices data calculated with the climdex library through
# an ad hoc pre-processing.
#  
# Details
# The following indices are calculated based on input daily precipitation data:
# PRY = mean annual precipitation
# INT = mean annual precipitation intensity (intensity during wet days, or simple precipitation intensity index SDII)
# WSL = mean annual wet spell length (number of consecutive days during each wet spell)
# DSL = mean annual dry spell lenght (number of consecutive days during each dry spell)
# PA  = precipitation area (area over which of any given day precipitation occurs) 
# R95 = heavy precipitation index (percent of total precipitation above the 95% percentile of the reference distribution)
# HY-INT = hydroclimatic intensity. HY-INT = normalized(INT) x normalized(DSL).
#
# For EC-Earth data and then extended to any model and observational data, producing plots 
# of data vs. a reference dataset (e.g. ERA-INTERIM). Indices are normalized over a reference 
# period. Both absolute and normalized values are made available: users can select the indices 
# to be stored and plotted. The tool makes extensives use of the cfg_hyint configuration file
# for user selectable options and ease feeding needed inputs (e.g. region boundaries for timeseries 
# or value ranges and labels for figures).     
# 
# Required
# It reads daily precipitation data through ESMValTool. Input precipitation data are pre-processed 
# interpolating on a common grid set by the user in the cfg_hyint file.  
# R libraries:"tools","PCICt","ncdf4","maps"
#
# Optional 
# Several options can be selected via the configuration file, e.g. the provision of an
# external normalization functions for the indices; a reference climatology for the R95 index; type of plots; etc. 
#
# Caveats
# Spatial data selection based on elevation works only with regridding at 320x160 (or by producing by hand grid files at needed resolution) 
#
# Modification history
#    20171206-A_arno_en: modularized version accepting climdex indices  
#    20171010-A_arno_en: modularized version  
#    20170901-A_arno_en: 1st github version  
#
# ############################################################################

library(tools)

source('diag_scripts/aux/hyint/hyint_functions.R')
source('diag_scripts/aux/hyint/hyint_metadata.R')
source('diag_scripts/aux/hyint/hyint_preproc.R')
source('diag_scripts/aux/hyint/hyint_diagnostic.R')
source('diag_scripts/aux/hyint/hyint_etccdi_preproc.R')
source('diag_scripts/aux/hyint/hyint_trends.R')
source('diag_scripts/aux/hyint/hyint_plot_maps.R')
source('diag_scripts/aux/hyint/hyint_plot_trends.R')

source('interface_data/r.interface')
source('diag_scripts/lib/R/info_output.r')
source(diag_script_cfg)

print(diag_script_cfg)
## Do not print warnings
options(warn=0)

#diag_base = file_path_sans_ext(diag_script)
diag_base = "HyInt"
print(paste(diag_base,": starting routine"))

var0 <- variables[1]
field_type0 <- field_types[1]
info_output(paste0("<<<<<<<< Entering ", diag_script), verbosity, 4)
info_output("+++++++++++++++++++++++++++++++++++++++++++++++++", verbosity, 1)
info_output(paste0("plot - ", diag_script, " (var: ", var0, ")"), verbosity, 1)
info_output("+++++++++++++++++++++++++++++++++++++++++++++++++", verbosity, 1)

## Create working dirs if they do not exist
etccdi_dir=file.path(work_dir,"extremeEvents_main")
work_dir=file.path(work_dir, diag_base)
plot_dir=file.path(plot_dir, diag_base)

dir.create(plot_dir, showWarnings = FALSE)
dir.create(work_dir, showWarnings = FALSE)
dir.create(regridding_dir, showWarnings = FALSE)

## Run regridding and diagnostic
if (write_ncdf) { 
  for (model_idx in c(1:(length(models_name)))) {
    # Create regridding subdir
    dir.create(paste(regridding_dir,models_name[model_idx],sep="/"), showWarnings = FALSE)   
    # Setup filenames 
    climofile <- interface_get_fullpath(var0, field_type0, model_idx)
    sgrid <- "noregrid"; if (rgrid != F) {sgrid <- rgrid}
    inregfile <- getfilename.regridded(regridding_dir,sgrid,var0,model_idx)
    # If needed, pre-process file regridding, selecting lon/lat region of interest and adding absolute time axis 
    if (run_regridding) {
      if(!file.exists(inregfile) | force_processing) { 
        dummy=hyint.preproc(work_dir,model_idx,climofile,inregfile)
      } else {
        print(paste0(diag_base,": data file exists: ", inregfile))  
      }
    }

    if (run_diagnostic) {    
      # Loop through seasons and call diagnostic
      for (seas in seasons) {
         hyint.diagnostic(work_dir,inregfile,model_idx,seas)
      }
    }
  }
}

## Preprocess ETCCDI input files and merge them with HyInt indices
if (write_ncdf & etccdi_preproc) {
  for (model_idx in c(1:(length(models_name)))) {
    dummy<-hyint.etccdi.preproc(work_dir,etccdi_dir,grid_file,model_idx,"ALL",yrmon="yr")
  }
}

## Calculate timeseries and trends
if (write_ncdf & run_timeseries) { 
  for (model_idx in c(1:(length(models_name)))) {
    for (seas in seasons) {
      hyint.trends(work_dir,model_idx,seas) 
    }
  }
}


## Create figures
if (write_plots) { 
  ref_idx=which(models_name == var_attr_ref) # select reference dataset; if not available, use last of list
  if(length(ref_idx)==0) { ref_idx=length(models_name)}
  for (seas in seasons) {
    if (plot_type <= 10) { # Plot maps
      hyint.plot.maps(work_dir,plot_dir,work_dir,ref_idx,seas) 

    } else { # Plot timeseries and trends
      print("HyInt: calling plot.trend")  
      hyint.plot.trends(work_dir,plot_dir,work_dir,ref_idx,seas)  
    }
  }
}
info_output(paste0(">>>>>>>> Leaving ", diag_script), verbosity, 4)

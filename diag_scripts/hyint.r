# #############################################################################
# hyint.r
# Authors:       E. Arnone (ISAC-CNR, Italy)
#	         J. von Hardenberg (ISAC-CNR, Italy) 
# #############################################################################
# Description
# HyInt is a tool for calculation of the HY-INT (Giorgi et al. 2011) diagnostic
# which allows an estimate of the overall behaviour of the hydroclimatic cycle. It
# joins together precipitation intensity (INT) and dry spells lenght (DSL): HY-INT = INT x DSL.
#   
# Details
# A day is defined as dry (wet) if the daily precipitation amount is below (above) 1 mm (Salinger and Griffiths 2001).
# INT = mean annual precipitation intensity (intensity during wet days)
# DSL = mean annual dry spell lenght (number of consecutive days during each dry spell)
# INT and DSL are normalized over given XX century mean value (depending on data availability)
#
# For EC-Earth output and then extended to any model and observational data.
# It works on daily precipitation data and it produces climatological figures 
# for the chosen time period. Data are interpolated on a common grid set by the user in the cfg file.  
# Model and observational data are compared against ECMWF ERA-INTERIM reanalysis for the chosen period.
#
# Required
#
# Optional 
#
# Caveats
# TODO: Missing obs data: only years with >= 300 days are included (further discarding spells interrupted by missing data) 
#
# Modification history
#  
#
# ############################################################################

source('diag_scripts/aux/hyint/basis_functions.R')
source('diag_scripts/aux/hyint/hyint_diagnostic.R')
source('diag_scripts/aux/hyint/hyint_figures.R')

source('interface_data/r.interface')
source('diag_scripts/lib/R/info_output.r')
source(diag_script_cfg)

## Do not print warnings
options(warn=0)

diag_base = "HyInt"
print(paste(diag_base,": starting routine"))

var0 <- variables[1]
field_type0 <- field_types[1]
info_output(paste0("<<<<<<<< Entering ", diag_script), verbosity, 4)
info_output("+++++++++++++++++++++++++++++++++++++++++++++++++", verbosity, 1)
info_output(paste0("plot - ", diag_script, " (var: ", variables[1], ")"), verbosity, 1)
info_output("+++++++++++++++++++++++++++++++++++++++++++++++++", verbosity, 1)

library(tools)
#diag_base = file_path_sans_ext(diag_script)

## Create working dirs if they do not exist
work_dir=file.path(work_dir, diag_base)
plot_dir=file.path(plot_dir, diag_base)

dir.create(plot_dir, showWarnings = FALSE)
dir.create(work_dir, showWarnings = FALSE)
dir.create(climo_dir, showWarnings = FALSE)
dir.create(regridding_dir, showWarnings = FALSE)

## Run regridding and diagnostic
for (model_idx in c(1:(length(models_name)))) {
  # Setup parameters for calling diagnostic 
  exp    <- models_name[model_idx]
  year1  <- models_start_year[model_idx]
  year2  <- models_end_year[model_idx]
  infile <- interface_get_fullpath(var0, field_type0, model_idx)
  model_exp <- models_experiment[model_idx]
  model_ens <- models_ensemble[model_idx]
  inregfile <- paste0(regridding_dir,"/",exp,"/",exp,"_",model_exp,"_",model_ens,"_",toString(year1),"-",toString(year2),"_",var0,"_",rgrid,".nc")

  # If needed, pre-process file regridding, selecting lon/lat region of interest and adding absolute time axis 
  if(!file.exists(inregfile) | force_processing) { 
    cdo_command<-paste(paste0("cdo -L -f nc -a -sellonlatbox,",paste(rlonlatdata,sep="",collapse=",")), 
                       paste0("-remapcon2,", rgrid), infile, paste0(inregfile,"regtmp"))
    cdo_command2<-paste("cdo -f nc4 -copy ", paste0(inregfile,"regtmp"), inregfile)
    rm_command<-paste("rm ", paste0(inregfile,"regtmp"))
    print(paste0(diag_base,": pre-processing file: ", infile))
    system(cdo_command)
    system(cdo_command2)
    system(rm_command)
    print(paste0(diag_base,": pre-processed file: ", inregfile))
  } else {
    print(paste0(diag_base,": data file exists: ", inregfile))  
  }
  if (run_diagnostic) {    
    # Loop through files and call diagnostic
    for (seas in seasons) {
       hyint.diagnostic(exp=exp,year1=year1,year2=year2,season=seas,model_idx=model_idx,infile=inregfile,work_dir=work_dir,diag_script_cfg)
    }
  }
}

## Plotting
if (write_plots) { 
  nregions=length(selregions)
  if (boxregion) { nregions=1 } # if overplotting region boxes use global map only
  if (plot_type > 4) { nregions=1 } # if working on timeseries skip loop on regions here
  ref_idx=which(models_name == var_attr_ref) # select reference dataset; if not available, use last of list
  if(length(ref_idx)==0) {
     ref_idx=length(models_name);
  }
  dataset_ref=models_name[ref_idx]
  model_exp_ref=models_experiment[ref_idx]
  model_ens_ref=models_ensemble[ref_idx]
  year1_ref=models_start_year[ref_idx]
  year2_ref=models_end_year[ref_idx]
  for (model_idx in c(1:(length(models_name)))) {
    if((model_idx != ref_idx)|(force_ref)) {
      exp <- models_name[model_idx]
      model_exp=models_experiment[model_idx]
      model_ens=models_ensemble[model_idx]
      year1=models_start_year[model_idx]
      year2=models_end_year[model_idx]
      for (seas in seasons) {
        for (iselregion in 1:nregions) {
          iregion=selregions[iselregion]
          hyint.figures(exp=exp,model_exp=model_exp,model_ens=model_ens,year1=year1,year2=year2,
                        dataset_ref=dataset_ref,model_exp_ref=model_exp_ref,model_ens_ref=model_ens_ref,year1_ref=year1_ref,year2_ref=year2_ref,
                          season=seas,plot_dir=plot_dir, work_dir=work_dir,ref_dir=work_dir,diag_script_cfg=diag_script_cfg,iregion=iregion)
        }
      }
    }
  }
}
info_output(paste0(">>>>>>>> Leaving ", diag_script), verbosity, 4)

# #############################################################################
# rainfarm.r
# Authors:       E. Arnone (ISAC-CNR, Italy)
#	         J. von Hardenberg (ISAC-CNR, Italy) 
# #############################################################################
# Description
# ESMValTool diagnostic calling the RainFARM library written in Julia (by von Hardenberg, ISAC-CNR, Italy).
# RainFARM is a stochastic precipitation downscaling method, further adapted for climate downscaling.
#  
# Required
# CDO
# Julia language: https://julialang.org
# RainFARM Julia library: https://github.com/jhardenberg/RainFARM.jl
#
# Optional 
#
# Caveats
#
# Modification history
#    20170908-A_arnone_e: 1st github version  
#
# ############################################################################

source('interface_data/r.interface')
source('diag_scripts/lib/R/info_output.r')
source(diag_script_cfg)

## Do not print warnings
options(warn=0)

diag_base = "RainFARM"
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

dir.create(work_dir, showWarnings = FALSE)
dir.create(regridding_dir, showWarnings = FALSE)

# Loop through input models, apply pre-processing and call RainFARM
for (model_idx in c(1:(length(models_name)))) {
  # Setup parameters and path 
  exp    <- models_name[model_idx]
  year1  <- models_start_year[model_idx]
  year2  <- models_end_year[model_idx]
  infile <- interface_get_fullpath(var0, field_type0, model_idx)
  model_exp <- models_experiment[model_idx]
  model_ens <- models_ensemble[model_idx]
  sgrid <- "noregrid"
  if (rgrid != F) {sgrid <- rgrid} 
  inregname <- paste0(exp,"_",model_exp,"_",model_ens,"_",toString(year1),"-",toString(year2),"_",var0,"_",sgrid,
                      "_",paste(rlonlatdata,collapse="-"))
  inregfile <- paste0(regridding_dir,"/",exp,"/",inregname,".nc")

  # If needed, pre-process file regridding, selecting a limited lon/lat region of interest and adding absolute time axis 
  if((!file.exists(inregfile) | force_processing)) { 
    sgrid<-""
    if (rgrid != F) {sgrid <- paste0("-remapcon2,", rgrid)}
    cdo_command<-paste(paste0("cdo -L -f nc -a -sellonlatbox,",paste(rlonlatdata,sep="",collapse=",")), 
                       sgrid, infile, paste0(inregfile,"regtmp"))
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

  # Call diagnostic
  dir.create(paste0(work_dir,"/",exp), showWarnings = FALSE)
  print(paste0(diag_base,": calling rainfarm"))
  filename <- paste0(work_dir,"/",exp,"/",inregname,"_downscaled") 

  # reformat arguments from cfg_file
  if (rainfarm_args$conserv_glob == T) {rainfarm_args$conserv_glob <- ""}
  if (rainfarm_args$conserv_smooth == T) {rainfarm_args$conserv_smooth <- ""}
 
  # generate weights file if needed
  # (for more information use 'rfweights -h')
  if (rainfarm_args$weights_climo != F) {
    fileweights <- paste0(work_dir,"/",exp,"/",inregname,"_w.nc")
    snf <- ""
    if (rainfarm_args$nf != F) {snf <- paste("-n ",rainfarm_args$nf)}
    command_w<-paste("rfweights -w ",fileweights,snf," -c ",rainfarm_args$weights_climo,inregfile)  
    print(paste0(diag_base,": generating weights file"))
    print(fileweights)
    system(command_w)
    #print(command_w)
    rainfarm_args$weights_climo<-fileweights
  }  
  ret <- which(as.logical(rainfarm_args)!=F|is.na(as.logical(rainfarm_args)))
  rargs <- paste(rainfarm_options[ret],rainfarm_args[ret],collapse=" ")
  # call rfarm
  # (for more information use 'rfarm -h')
  command<-paste0("rfarm -o '", filename,"' ",rargs," ",inregfile) 
  #print(command)
  system(command)
  print(paste0(diag_base,": downscaled data written to ",paste0(filename,"_*.nc")))
}

info_output(paste0(">>>>>>>> Leaving ", diag_script), verbosity, 4)

######################################################
#---------Regridding preprocessing for HyInt---------#
#-------------E. Arnone (Oct 2017)-------------------#
######################################################

hyint.preproc<-function(work_dir,model_idx,climofile,inregfile) {

#  absolute axis, remove leap year days, select lonlat box convert to NetCDF4

  sgrid<-""
  if (rgrid != F) {sgrid <- paste0("-remapcon2,", rgrid)}
  cdo_command<-paste(paste0("cdo -L -f nc -a -delete,month=2,day=29 -sellonlatbox,",paste(rlonlatdata,sep="",collapse=",")),
                     sgrid, climofile, paste0(inregfile,"regtmp"))
  cdo_command2<-paste("cdo -f nc4 -copy ", paste0(inregfile,"regtmp"), inregfile)
  rm_command<-paste("rm ", paste0(inregfile,"regtmp"))
  print(paste0(diag_base,": pre-processing file: ", climofile))
  system(cdo_command); system(cdo_command2); system(rm_command)
  print(paste0(diag_base,": pre-processed file: ", inregfile))

return(0)
}

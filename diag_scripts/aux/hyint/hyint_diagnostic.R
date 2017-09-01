######################################################
#-----Hydroclimatic Intensity (HyInt) diagnostic-----#
#-------------E. Arnone (June 2017)------------------#
######################################################
hyint.diagnostic<-function(exp,year1,year2,season,model_idx,infile,work_dir,diag_script_cfg) {

source(diag_script_cfg)

# t0
t0<-proc.time()
diag_base="HyInt"

# setting up path and parameters
save_dir=file.path(work_dir,exp,paste0(year1,"_",year2),season)
#outfile<-paste0(save_dir,"/Hyint_",exp,"_",rgrid,"_",year1,"_",year2,"_",season,".nc")
outfile<-paste0(save_dir,"/Hyint_",exp,"_",model_exp,"_",model_ens,"_",rgrid,"_",toString(year1),"_",toString(year2),"_",season,".nc")

# If diagnostic output file already exists skip calculation
if(file.exists(outfile) & !force_calc) { 
  print(paste0(diag_base,": output file already exists:",outfile)) 
  print(paste0(diag_base,": skipping calculation"))
  return()
} 

# create output directory
dir.create(save_dir,recursive=T)

# setting up time domain
years=year1:year2
timeseason=season2timeseason(season)

# new file opening
fieldlist=ncdf.opener.time(infile,"pr",tmonths=timeseason,tyears=years,rotate="full")
print(str(fieldlist))

# time array
datas=fieldlist$time
#etime=list(day=as.numeric(format(datas,"%d")),month=as.numeric(format(datas,"%m")),year=as.numeric(format(datas,"%Y")),data=datas)
etime=power.date.new(datas)

# declare and convert variable
pr=fieldlist$field*86400.   # convert (Kg m-2 s-1) to (mm day-1) 
ntime=length(pr[1,1,])

#############################################################
#--------Indices calculation (Giorgi et al. 2011/14)----------#
#############################################################

# Setup useful arrays and parameters
nyear<-length(years)
pry=pr[,,1:nyear]*NA # annual mean precipitation (over all days)
int=pr[,,1:nyear]*NA # mean precipitation intensity (over wet days, SDII)
dsl=pr[,,1:nyear]*NA # mean dry spell length (DSL)
wsl=pr[,,1:nyear]*NA # mean wet spell length (WSL)
pa=pr[,,1:nyear]*NA  # precipitation area (PA)
pry_norm<-pry
int_norm<-int
dsl_norm<-dsl
wsl_norm<-wsl
pa_norm<-pa

# Calculate indices
for (iyear in 1:nyear) {
  ret_year<-which(etime$year==years[iyear])
  pr_year<-pr[,,ret_year]

  # Identify dry and wet days (Salinger and Griffiths 2001)
  ret_dry<-(pr_year < 1)      # Dry days when pr < 1 mm
  ret_wet<-(pr_year >= 1)     # Rainy days when pr >= 1 mm
  pr_year_dry<-pr_year*0. ; pr_year_dry[ret_dry]<-1 # mask with 1 for dry day 
  pr_year_wet<-pr_year*0. ; pr_year_wet[ret_wet]<-1 # mask with 1 for rainy day  
  pr_year_int<-pr_year    ; pr_year_int[ret_dry]<-NA # actual precipitation but with NA on dry days  

  # Mean annual precipitation
  pry_year<-apply(pr_year,c(1,2),mean,na.rm=T) 

  # Mean annual precipitation intensity (intensity during wet days)
  int_year<-apply(pr_year_int,c(1,2),mean,na.rm=T) 

  # Mean annual dry spell length (DSL; number of consecutive dry days during each dry spell).
  dsl_year<-mean.spell.length(pr_year_dry)

  # Mean annual wet  spell length (WSL; number of consecutive wet days during each wet spell).
  wsl_year<-mean.spell.length(pr_year_wet)

  # Precipitation area (number of rainy days * area of grid box)
  area_size=area.size(ics,ipsilon)
  print(str(area_size))
  print(str(pr_year_wet))
  pa_year<-(apply(pr_year_wet,c(1,2),sum,na.rm=T))*area_size

  # Assign in-loop variables to storage array
  pry[,,iyear]<-pry_year 
  dsl[,,iyear]<-dsl_year 
  wsl[,,iyear]<-wsl_year 
  int[,,iyear]<-int_year 
  pa[,,iyear]<-pa_year 
} 

# remove desert areas if required (mean annual precipitation <0.5 mm, Giorgi et al. 2014)
if (removedesert) {
  retdes=which(pry<0.5)
  pry[retdes]=NA
  retdes2D=apply(pry*0,c(1,2),sum)+1 # create mask with NAs for deserts and 1's for not-desert
  retdes3D=replicate(nyear,retdes2D) # replicate for number of years
  pry=pry*retdes3D
  dsl=dsl*retdes3D
  wsl=wsl*retdes3D
  int=int*retdes3D
  pa=pa*retdes3D
}

# Normalize to available XX century data
# NOTE: take care of normalization by 0: when the normalizing function is 0 (e.g. short dataset < 2000), the resulting normalized index will be NA.

if (external_norm[1]==F) { # calculate average over requested period 
  ret_years<-which(years < norm_year_cutoff)
  if (length(ret_years)<3) {stop("HyInt: not enough XX century data, unable to normalize")}
  pry_mean<-apply(pry[,,ret_years],c(1,2),mean,na.rm=T)
  dsl_mean<-apply(dsl[,,ret_years],c(1,2),mean,na.rm=T)
  wsl_mean<-apply(wsl[,,ret_years],c(1,2),mean,na.rm=T)
  int_mean<-apply(int[,,ret_years],c(1,2),mean,na.rm=T)
  pa_mean<-apply(pa[,,ret_years],c(1,2),mean,na.rm=T)
  pry_mean_sd<-apply(pry[,,ret_years],c(1,2),sd,na.rm=T)
  dsl_mean_sd<-apply(dsl[,,ret_years],c(1,2),sd,na.rm=T)
  wsl_mean_sd<-apply(wsl[,,ret_years],c(1,2),sd,na.rm=T)
  int_mean_sd<-apply(int[,,ret_years],c(1,2),sd,na.rm=T)
  pa_mean_sd<-apply(pa[,,ret_years],c(1,2),sd,na.rm=T)

} else { # load normalization data from file
  mean_idx<-model_idx # assume each model has its normalization file
  if (length(external_norm) == 1) { mean_idx<-1 } # if list of files with normalization functions has only 1 entry, use that for all models
  print(paste(diag_base,": loading external normalization data from ",external_norm[mean_idx]))
  pry_mean<-ncdf.opener(external_norm[mean_idx],"pry_mean","Lon","Lat",rotate="no")
  dsl_mean<-ncdf.opener(external_norm[mean_idx],"dsl_mean","Lon","Lat",rotate="no")
  wsl_mean<-ncdf.opener(external_norm[mean_idx],"wsl_mean","Lon","Lat",rotate="no")
  int_mean<-ncdf.opener(external_norm[mean_idx],"int_mean","Lon","Lat",rotate="no")
  pa_mean<-ncdf.opener(external_norm[mean_idx],"pa_mean","Lon","Lat",rotate="no")
  pry_mean_sd<-ncdf.opener(external_norm[mean_idx],"pry_mean_sd","Lon","Lat",rotate="no")
  dsl_mean_sd<-ncdf.opener(external_norm[mean_idx],"dsl_mean_sd","Lon","Lat",rotate="no")
  wsl_mean_sd<-ncdf.opener(external_norm[mean_idx],"wsl_mean_sd","Lon","Lat",rotate="no")
  int_mean_sd<-ncdf.opener(external_norm[mean_idx],"int_mean_sd","Lon","Lat",rotate="no")
  pa_mean_sd<-ncdf.opener(external_norm[mean_idx],"pa_mean_sd","Lon","Lat",rotate="no")
}

# perform normalization
for (iyear in 1:nyear) {
  pry_norm[,,iyear]=pry[,,iyear]/pry_mean
  dsl_norm[,,iyear]=dsl[,,iyear]/dsl_mean
  wsl_norm[,,iyear]=wsl[,,iyear]/wsl_mean
  int_norm[,,iyear]=int[,,iyear]/int_mean
  pa_norm[,,iyear]=pa[,,iyear]/pa_mean
}

# HyInt index
hyint = dsl_norm * int_norm

# HyInt list
hyint_list<-list(pry=pry,dsl=dsl,wsl=wsl,int=int,pa=pa,
                 pry_mean=pry_mean,dsl_mean=dsl_mean,wsl_mean=wsl_mean,int_mean=int_mean,pa_mean=pa_mean,
                 pry_mean_sd=pry_mean_sd,dsl_mean_sd=dsl_mean_sd,wsl_mean_sd=wsl_mean_sd,int_mean_sd=int_mean_sd,pa_mean_sd=pa_mean_sd,
                 pry_norm=pry_norm,dsl_norm=dsl_norm,wsl_norm=wsl_norm,int_norm=int_norm,pa_norm=pa_norm,hyint=hyint)

print(paste(diag_base,": calculation done. Returning mean precipitation, sdii, dsl, wsl, pa (absolute and normalized values) and hyint indices"))
#return(hyint)


##########################################################
#------------------------Save to NetCDF------------------#
##########################################################

# saving output to netcdf files
print(paste(diag_base,": saving data to NetCDF file:"))

# define fieds to be saved
fieldlist<-c("pry","dsl","wsl","int","pa","pry_mean","dsl_mean","wsl_mean","int_mean","pa_mean",
             "pry_mean_sd","dsl_mean_sd","wsl_mean_sd","int_mean_sd","pa_mean_sd",
             "pry_norm","dsl_norm","wsl_norm","int_norm","pa_norm","hyint")

# dimensions definition
x <- ncdim_def( "Lon", "degrees", ics)
y <- ncdim_def( "Lat", "degrees", ipsilon)
t <- ncdim_def( "Time", "years", years,unlim=T)

for (var in fieldlist){
  field <- get(var,hyint_list)
  field[is.nan(field)]=NA
  metadata <- getmetadata.indices(var)
  longvar <- metadata$longvar
  unit    <- metadata$unit
  #variable definitions
  var_ncdf=ncvar_def(var,unit,list(x,y,t),-999,longname=longvar,prec="single",compression=1)  
  if ((var=="pry_mean")|(var=="int_mean")|(var=="dsl_mean")|(var=="wsl_mean")|(var=="pa_mean")|
      (var=="pry_mean_sd")|(var=="int_mean_sd")|(var=="dsl_mean_sd")|(var=="wsl_mean_sd")|(var=="pa_mean_sd")) { 
    var_ncdf=ncvar_def(var,unit,list(x,y),-999,longname=longvar,prec="single",compression=1)
  }
  assign(paste0("var",var),var_ncdf)
  assign(paste0("field",var),field)
}

# Netcdf file creation
print(paste(diag_base,": saving output to ",outfile))
namelist=paste0("var",fieldlist)
nclist <- mget(namelist)
ncfile <- nc_create(outfile,nclist)
for (var in fieldlist)
{
  # put variables into the ncdf file
  print("------------------")
  print(var)
  ndims=get(paste0("var",var))$ndims
  ncvar_put(ncfile, var, get(paste0("field",var)), start = rep(1,ndims),  count = rep(-1,ndims))
}
nc_close(ncfile)
print(paste(diag_base,": netCDF files saved"))
}

# REAL EXECUTION OF THE SCRIPT 
# read command line
args <- commandArgs(TRUE)

# number of required arguments from command line
name_args=c("exp","year1","year2","season","model_idx","rgrid","rlonlatdata","infile","work_dir")
req_args=length(name_args)

# print error message if uncorrect number of command 
if (length(args)!=0) {
    if (length(args)!=req_args) {
        print(paste("Not enough or too many arguments received: please specify the following",req_args,"arguments:"))
        print(name_args)
    } else {
# when the number of arguments is ok run the function()
        for (k in 1:req_args) {assign(name_args[k],args[k])}
        source(paste0(PROGDIR,"/script/basis_functions.R"))
        hyint.diagnostic(exp,year1,year2,season,model_idx,infile,work_dir,diag_script_cfg)
    }
}


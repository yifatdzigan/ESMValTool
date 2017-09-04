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


##########################################################
#--------HyInt calculation (Giorgi et al. 2011)----------#
##########################################################

# Setup useful arrays and parameters
nyear<-length(years)
int=pr[,,1:nyear]*NA
dsl=pr[,,1:nyear]*NA
int_norm<-int
dsl_norm<-dsl

# Loop through years
for (iyear in 1:nyear)
 {
 ret_year<-which(etime$year==years[iyear])
 pr_year<-pr[,,ret_year]

 # Identify dry and wet days (Salinger and Griffiths 2001)
 ret_dry<-(pr_year < 1)      # Dry days when pr < 1 mm
 ret_wet<-(pr_year >= 1)     # Rainy days when pr >= 1 mm
 pr_year_dry<-pr_year*0. ; pr_year_dry[ret_dry]<-1 
 pr_year_wet<-pr_year ; pr_year_wet[ret_dry]<-NA   

 # Mean annual precipitation intensity (intensity during wet days)
 int_year<-apply(pr_year_wet,c(1,2),mean,na.rm="TRUE") 

 # Mean annual dry spell length (DSL; number of consecutive dry days during each dry spell).
 dsl_year<-mean.spell.length(pr_year_dry)

 # Assign in-loop variables to storage array
 dsl[,,iyear]<-dsl_year 
 int[,,iyear]<-int_year 
} 

# Normalize to available XX century data
# NOTE: take care of normalization by 0: when the normalizing function is 0 (e.g. short dataset < 2000), the resulting normalized index will be NA.

if (external_norm[1]==F) { # calculate average over requested period 
  ret_years<-which(years < norm_year_cutoff)
  if (length(ret_years)==0) {stop("HyInt: no XX century data, unable to normalize")}
  dsl_mean<-apply(dsl[,,ret_years],c(1,2),mean,na.rm="TRUE")
  int_mean<-apply(int[,,ret_years],c(1,2),mean,na.rm="TRUE")
  dsl_mean_sd<-apply(dsl[,,ret_years],c(1,2),sd,na.rm="TRUE")
  int_mean_sd<-apply(int[,,ret_years],c(1,2),sd,na.rm="TRUE")
} else { # load normalization data from file
  print(paste(diag_base,": loading external normalization data from ",external_norm[model_idx]))
  dsl_mean<-ncdf.opener(external_norm[model_idx],"dsl_mean","Lon","Lat",rotate="no")
  int_mean<-ncdf.opener(external_norm[model_idx],"int_mean","Lon","Lat",rotate="no")
  dsl_mean_sd<-ncdf.opener(external_norm[model_idx],"dsl_mean_sd","Lon","Lat",rotate="no")
  int_mean_sd<-ncdf.opener(external_norm[model_idx],"int_mean_sd","Lon","Lat",rotate="no")
}

# perform normalization
for (iyear in 1:nyear) {
  dsl_norm[,,iyear]=dsl[,,iyear]/dsl_mean
  int_norm[,,iyear]=int[,,iyear]/int_mean
}
print(str(dsl_norm))

# HyInt index
hyint = dsl_norm * int_norm

# HyInt list
hyint_list<-list(dsl=dsl,int=int,dsl_mean=dsl_mean,int_mean=int_mean,dsl_mean_sd=dsl_mean_sd,int_mean_sd=int_mean_sd,dsl_norm=dsl_norm,int_norm=int_norm,hyint=hyint)

print(paste(diag_base,": calculation done. Returning int, dsl (absolute and normalized values) and hyint indices"))
#return(hyint)


##########################################################
#------------------------Save to NetCDF------------------#
##########################################################

# saving output to netcdf files
print(paste(diag_base,": saving data to NetCDF file:"))

# define fieds to be saved
fieldlist<-c("dsl","int","dsl_mean","int_mean","dsl_mean_sd","int_mean_sd","dsl_norm","int_norm","hyint")

# dimensions definition
x <- ncdim_def( "Lon", "degrees", ics)
y <- ncdim_def( "Lat", "degrees", ipsilon)
t <- ncdim_def( "Time", "years", years,unlim=T)

for (var in fieldlist)
{
        #name of the var
	if (var=="dsl")         {longvar="Annual mean dry spell length"; unit="days"; field=hyint_list$dsl}
	if (var=="dsl_mean")    {longvar="Normalization function: Annual mean dry spell length averaged over available XX century data"; 
                                 unit="days"; field=hyint_list$dsl_mean}
	if (var=="dsl_mean_sd")      {longvar="Normalization function: Standard deviation of the annual mean dry spell length averaged over available XX century data"; 
                                 unit="days"; field=hyint_list$dsl_mean_sd}
	if (var=="dsl_norm")    {longvar="Normalized annual mean dry spell length"; unit=""; field=hyint_list$dsl_norm}
	if (var=="int")         {longvar="Annual mean precipitation intensity"; unit="mm day-1"; field=hyint_list$int}
	if (var=="int_mean")    {longvar="Normalization function: Annual mean precipitation intensity averaged over 
                                 available XX century data"; unit="mm day-1"; field=hyint_list$int_mean}
	if (var=="int_mean_sd")      {longvar="Normalization function: Standard deviation of the annual mean precipitation intensity averaged over 
                                 available XX century data"; unit="mm day-1"; field=hyint_list$int_mean_sd}
	if (var=="int_norm")    {longvar="Normalized annual mean precipitation intensity"; unit=""; field=hyint_list$int_norm}
	if (var=="hyint")       {longvar="Hydroclimatic intensity index"; unit=""; field=hyint_list$hyint}

	#fix eventual NaN	
	field[is.nan(field)]=NA

        #variable definitions
        var_ncdf=ncvar_def(var,unit,list(x,y,t),-999,longname=longvar,prec="single",compression=1)
     
        if ((var=="int_mean")|(var=="dsl_mean")|(var=="int_mean_sd")|(var=="dsl_mean_sd")) { 
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


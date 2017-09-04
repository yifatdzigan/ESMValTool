######################################################
#-----------Plotting froutine for HyInt--------------#
#-------------E. Arnone (June 2017)------------------#
######################################################

#DECLARING THE FUNCTION: EXECUTION IS AT THE BOTTOM OF THE SCRIPT
hyint.figures<-function(exp,year1,year2,dataset_ref,year1_ref,year2_ref,season, FIGDIR,FILESDIR,REFDIR,CFGSCRIPT)
{

#figures configuration files
source(CFGSCRIPT)

#set main paths
HYINTDIR=file.path(FILESDIR,exp,paste0(year1,"_",year2),season)
FIGDIRHYINT=file.path(FIGDIR,exp,paste0(year1,"_",year2),season)
dir.create(FIGDIRHYINT,recursive=T)

#check path for reference dataset
#if (dataset_ref=="ERAINTERIM" & year1_ref=="1979" & year2_ref=="2014")
if (REFDIR!=FILESDIR)
        {REFDIR=file.path(REFDIR,"HyInt")} else {REFDIR=paste(FILESDIR,"/",dataset_ref,"/",year1_ref,"_",year2_ref,"/",season,"/",sep="")}

#which fieds to load/plot
fieldlist=c("dsl","dsl_norm","int","int_norm","hyint_index")

# Set useful parameters and arrays
years=year1:year2
years_ref=year1_ref:year2_ref
# Loop over years 
for (iyear in years-years[1]+1){
#iyear=5
iyear_ref=iyear
#lat_lim=c(35,70) 
lat_lim= c(-90,90)
#lon_lim=c(-10,30) 
lon_lim= c(-180,180)


##########################################################
#-----------------Loading datasets-----------------------#
##########################################################

#open experiment field
for (field in fieldlist) 
	{
        nomefile=paste0(HYINTDIR,"/Hyint_",exp,"_",year1,"_",year2,"_",season,".nc")
        field_exp=ncdf.opener(nomefile,field,"Lon","Lat",rotate="no")
        assign(paste(field,"_exp",sep=""),field_exp)
}

#open reference field
for (field in fieldlist) 
	{
     	nomefile=paste0(REFDIR,"Hyint_",dataset_ref,"_",year1_ref,"_",year2_ref,"_",season,".nc")
     	field_ref=ncdf.opener(nomefile,field,"Lon","Lat",rotate="no")
     	assign(paste(field,"_ref",sep=""),field_ref)
}

##########################################################
#-----------------Produce figures------------------------#
##########################################################

# set reference year for plotting
field_ref<-field_ref[,,iyear]
field_exp<-field_exp[,,iyear_ref]
print("******starting fields********")
print(paste0("year: ",years[iyear]))
print(str(field_exp))
print(str(field_ref))

#standard properties
legend_distance=3
#info_exp=paste(exp,year1,"-",year2,season)
info_exp=paste(exp,years[iyear],season)
#info_ref=paste(dataset_ref,year1_ref,"-",year2_ref,season)
info_ref=paste(dataset_ref,years_ref[iyear_ref],season)

#loop on fields
for (field in fieldlist) {

	#define field-dependent properties
	if (field=="dsl") {
		color_field=palette1; color_diff=palette2
		lev_field=seq(0,24,0.6); lev_diff=seq(-10,10,1)
		legend_unit="Annual mean DSL (days)"; title_name="Annual mean dry spell length:"; 
	}
        if (field=="dsl_norm") {
                color_field=palette1; color_diff=palette2
                lev_field=seq(0.4,1.6,0.02); lev_diff=seq(-1.2,1.2,0.1)
                legend_unit="Normalized annual mean DSL"; title_name="Normalized annual mean dry spell length:";
        }
        if (field=="int") {
                color_field=palette1; color_diff=palette2
                lev_field=seq(0,10,0.5); lev_diff=seq(-10,10,1)
                legend_unit="Annual mean INT (mm/day)"; title_name="Annual mean precipitation intensity:";
        }
        if (field=="int_norm") {
                color_field=palette1; color_diff=palette2
                lev_field=seq(0.4,1.6,0.1); lev_diff=seq(-1.2,1.2,0.1)
                legend_unit="Normalized annual mean INT"; title_name="Normalized annual mean precipitation intensity:";
        }
        if (field=="hyint_index") {
                color_field=palette1; color_diff=palette2
                lev_field=seq(0.4,1.6,0.1); lev_diff=seq(-1.2,1.2,0.1)
                legend_unit="HyInt"; title_name="Hydroclimatic intensity:";
        }

	#get fields
        field_ref=get(paste(field,"_ref",sep=""))
        field_exp=get(paste(field,"_exp",sep=""))
        field_ref=field_ref[,,iyear] 
        field_exp=field_exp[,,iyear_ref] 


	#secondary plot properties
	nlev_field=length(lev_field)-1
	nlev_diff=length(lev_diff)-1

	#final plot production
	figname=paste(FIGDIRHYINT,"/",field,"_",exp,"_",year1,"_",year2,"_",season,"_",years[iyear],".",output_file_type,sep="")
	print(figname)
	
	# Chose output format for figure - by JvH
        if (tolower(output_file_type) == "png") {
           png(filename = figname, width=png_width, height=png_height)
        } else if (tolower(output_file_type) == "pdf") {
            pdf(file=figname,width=pdf_width,height=pdf_height,onefile=T)
        } else if (tolower(output_file_type) == "eps") {
            setEPS(width=pdf_width,height=pdf_height,onefile=T,paper="special")
            postscript(figname)
        }

	#panels option
	par(mfrow=c(3,1),cex.main=2,cex.axis=1.5,cex.lab=1.5,mar=c(5,5,4,8),oma=c(1,1,1,1))

	#main experiment plot

	filled.contour3(ics,ipsilon,field_exp,xlab="Longitude",ylab="Latitude",main=paste(title_name,info_exp),levels=lev_field,color.palette=color_field,ylim=lat_lim, xlim=lon_lim)
	map("world",regions=".",interior=F,exact=F,boundary=T,add=T)

	#reference field plot
	filled.contour3(ics,ipsilon,field_ref,xlab="Longitude",ylab="Latitude",main=paste(title_name,info_ref),levels=lev_field,color.palette=color_field,ylim=lat_lim, xlim=lon_lim)
	map("world",regions=".",interior=F,exact=F,boundary=T,add=T)
	image.scale3(volcano,levels=lev_field,color.palette=color_field,colorbar.label=legend_unit,cex.colorbar=1.2,cex.label=1.5,colorbar.width=1,line.label=legend_distance,line.colorbar=1.5)

	#delta field plot
	filled.contour3(ics,ipsilon,field_exp-field_ref,xlab="Longitude",ylab="Latitude",main=paste(title_name,"Difference"),levels=lev_diff,color.palette=color_diff,ylim=lat_lim, xlim=lon_lim)
	map("world",regions=".",interior=F,exact=F,boundary=T,add=T)
	image.scale3(volcano,levels=lev_diff,color.palette=color_diff,colorbar.label=legend_unit,cex.colorbar=1.2,cex.label=1.5,colorbar.width=1,line.label=legend_distance,line.colorbar=1.5)

	dev.off()
	}
} # close loop on years
} # close function

# REAL EXECUTION OF THE SCRIPT 
# read command line
args <- commandArgs(TRUE)

# number of required arguments from command line
name_args=c("exp","year1","year2","dataset_ref","year1_ref","year2_ref","season","FIGDIR","FILESDIR","REFDIR","CFGSCRIPT","PROGDIR")
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
	hyint.figures(exp,year1,year2,dataset_ref,year1_ref,year2_ref,season,FIGDIR,FILESDIR,REFDIR,CFGSCRIPT) 
    }
}



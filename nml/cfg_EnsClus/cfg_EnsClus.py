# This is the configuration file for EnsClus.
# Comments are written like these lines at the beginning of this file.

#####################################################################
#
#  EnsClus configuration file
#
# About: configuration file for ESMValTool EnsClus namelist.
#
#####################################################################

# Information required:

#-------------------------------about data-------------------------------------------
# Write only letters or numbers, no punctuation marks!
# If you want to leave the field empty write 'no' 
diag_script_info = True

varunits="kg m-2 s-1"       #variable units (K, 'kg m-2 s-1')
numens=60                   #total number of ensemble members
season='JJA'                #seasonal average
area='Eu'                   #regional average (examples:'EAT':Euro-Atlantic
                            #                           'PNA': Pacific North American
                            #                           'NH': Northern Hemisphere)
                            #                           'Eu': Europe)
kind='hist'                 #hist: historical, scen:scenario
extreme='75th_percentile'   #75th_percentile, mean, maximum

#---------------------about cluster analysis------------------------------------------
numclus=6              #number of clusters
#Either set perc or numpcs:
perc=80                #cluster analysis is applied on a number of PCs such as they explain
                       #'perc' of total variance
numpcs='no'            #number of PCs

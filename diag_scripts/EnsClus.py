"""
;;#############################################################################
;; Ensemble Clustering Diagnostics
;; Author: Irene Mavilia (ISAC-CNR, Italy)
;; Copernicus C3S 34a lot 2 (MAGIC)
;;#############################################################################
;; Description
;;    Cluster analysis tool based on the k-means algorithm 
;;    for ensembles of climate model simulations
;;
;; Required diag_script_info attributes (diagnostics specific)
;;    none
;;
;; Optional diag_script_info attributes (diagnostic specific)
;;    none
;;
;; Required variable_info attributes (variable specific)
;;    none
;;
;; Optional variable_info attributes (variable specific)
;;    none
;;
;; Caveats
;;
;; Modification history
;;    20170710-A_mavi_ir: Routines written.
;;
;;#############################################################################
"""

# Basic Python packages
import sys
import imp

# Add subfolder of the diagnostics to the path
sys.path.append('./diag_scripts/aux/EnsClus/')

from esmval_lib import ESMValProject

# Import full diagnostic routines
from ens_anom import ens_anom
#from ens_eof_kmeans import ens_eof_kmeans 

def main(project_info):
    print(">>>>>>>> EnsClus.py is running! <<<<<<<<<<<<")

    E = ESMValProject(project_info)
    
    verbosity   = E.get_verbosity()
    diag_script = E.get_diag_script_name()
    config_file = E.get_configfile()
    plot_dir    = E.get_plot_dir()
    work_dir    = E.get_work_dir() 

    print('work_dir={0}'.format(work_dir))
        
    res = E.write_references(diag_script,              # diag script name
                             ["A_mavi_ir"],            # authors
                             [""],                     # contributors
                             [""],                     # diag_references
                             [""],                     # obs_references
                             [""],                     # proj_references
                             project_info,
                             verbosity,
                             False)

    f = open(project_info['RUNTIME']['currDiag'].diag_script_cfg)
    cfg = imp.load_source('cfg', '', f)
    f.close()

    datakeys = E.get_currVars()
    print('There is/are {0} variables'.format(len(datakeys)))
    for v in datakeys:
        print('variable is {0}'.format(v))
        
    #model_filelist=E.get_clim_model_filenames(variable=v)
    #print('filename is {0}'.format(model_filelist))
    #datakey=datakeys[0]
    #print(datakey)

    filename_array=[]
    model_filelist=E.get_clim_model_filenames(variable=datakeys[0])
    print('model_filename variabile is:\n{0}'.format(model_filelist))
    filename_array.append(model_filelist) 
    print(filename_array)
    print('\nPROJECT INFO:')
    print(project_info)    #.keys() .values()



    filename_array=[]
    for inc in range(len(project_info['MODELS'])):
        print(inc)
        model=project_info['MODELS'][inc]
        print(model)
#        # only for non-reference models
#        if not model.model_line.split()[1] == project_info['RUNTIME']['currDiag'].variables[v].ref_model:
#            model_filename=model_filelist[model.model_line.split()[1]]
#            reference_filename=model_filelist[project_info['RUNTIME']['currDiag'].variables[v].ref_model]
#        #model_filelist=E.get_model_data(modelconfig, experiment, area, datakey, datafile, extend='')
#        model_filelist=E.get_clim_model_filenames(variable==v)
#        #model_filename=model_filelist[model.model_line.split()[1]]
#        #model_filename=model_filelist[model.model_line.split()[1]]
#        #print(models_filelist)
#        print(model_filename)
#        #filename_array.append(model_filelist)i
#    #print('INPUT array of absolute filenames is {0}'.format(filename_array))
    
    #print(diag_script_info.area)
    name_outputs=datakey+'_'+str(cfg.numens)+'ens_'+cfg.season+'_'+cfg.area+'_'+cfg.kind
    print(name_outputs)
    #dir_OUTPUT=''
    
    #ens_anom()
   # ens_anom(filename_array,work_dir,name_outputs,cfg.varunits,cfg.extreme)

    #ens_eof_kmeans(???dir_OUTPUT,xxxxdir_PYtool,name_outputs,xxxxvarunits,cfg.numpcs,cfg.perc,cfg.numclus)

    print(">>>>>>>> ENDED SUCESSFULLY!! <<<<<<<<<<<<")
    print('')

if __name__ == "__main__":
    main()

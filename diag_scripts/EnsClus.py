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
from ens_eof_kmeans import ens_eof_kmeans 

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

    variables = E.get_currVars()
    print('There is/are {0} variables'.format(len(variables)))
    for v in variables:
        print('variable is {0}'.format(v))
        
    model_filelist=get_climo_filenames(E,variable=variables[0])
    print model_filelist

    #print('\nPROJECT INFO:')
    #print(project_info)    #.keys() .values()
     
    #print(diag_script_info.area)
    name_outputs=variables[0]+'_'+str(cfg.numens)+'ens_'+cfg.season+'_'+cfg.area+'_'+cfg.kind
    print(name_outputs)
    #dir_OUTPUT=''
    
    ens_anom(model_filelist,work_dir,name_outputs,variables[0],cfg.varunits,cfg.numens,cfg.season,cfg.area,cfg.extreme)

    ens_eof_kmeans(work_dir,name_outputs,cfg.varunits,cfg.numens,cfg.numpcs,cfg.perc,cfg.numclus)

    print(">>>>>>>> ENDED SUCESSFULLY!! <<<<<<<<<<<<")
    print('')

if __name__ == "__main__":
    main()



def get_climo_filenames(E, variable):

    import projects
    import os

    res = []

    for currDiag in E.project_info['DIAGNOSTICS']:
        variables = currDiag.get_variables()
        field_types = currDiag.get_field_types()
        mip = currDiag.get_var_attr_mip()
        exp = currDiag.get_var_attr_exp()
        for idx in range(len(variables)):
            for model in E.project_info['MODELS']:
                currProject = getattr(vars()['projects'],
                                      model.split_entries()[0])()
                fullpath = currProject.get_cf_fullpath(E.project_info,
                                                       model,
                                                       field_types[idx],
                                                       variables[idx],
                                                       mip[idx],
                                                       exp[idx])
                if variable == variables[idx] and os.path.isfile(fullpath):
                    res.append(fullpath)
    return res

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
import os

# Add subfolder of the diagnostics to the path
sys.path.append('./diag_scripts/aux/EnsClus/')
from esmval_lib import ESMValProject

# Import full diagnostic routines
from ens_anom import ens_anom
from ens_eof_kmeans import ens_eof_kmeans 
from ens_plots import ens_plots

def main(project_info):
    print('\n>>>>>>>>>>>> EnsClus.py is running! <<<<<<<<<<<<\n')

    E = ESMValProject(project_info)
    
    verbosity   = E.get_verbosity()
    diag_script = E.get_diag_script_name()
    config_file = E.get_configfile()
    plot_dir    = E.get_plot_dir()
    work_dir    = E.get_work_dir() 
    out_dir=work_dir
    print('work_dir={0}'.format(work_dir))
    print('out_dir={0}'.format(out_dir))

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

    # Creating the log file in the Log directory
    if not os.path.exists(out_dir+'Log'):
        os.mkdir(out_dir+'Log')
    class Tee(object):
        def __init__(self, *files):
            self.files = files
        def write(self, obj):
            for f in self.files:
                f.write(obj)
                f.flush() # If you want the output to be visible immediately
        def flush(self) :
            for f in self.files:
                f.flush()
    
    f = open(out_dir+'Log/Printed_messages.txt', 'w')
    original = sys.stdout
    sys.stdout = Tee(sys.stdout, f)

    variables = E.get_currVars()
    if len(variables)==1:
        print('There is 1 input variable')
    else:
        print('There are {0} input variables'.format(len(variables)))
    for v in variables:
        print('variable is {0}'.format(v))
        
    model_filelist=get_climo_filenames(E,variable=variables[0])
    print('_____________________________\n{0} INPUT FILES:'.format(len(model_filelist)))
    for i in model_filelist:
        print i
    print('_____________________________\n')

    #print('\nPROJECT INFO:')
    #print(project_info)    #.keys() .values()
    #print(diag_script_info.area)

    #____________Building the name of output files
    name_outputs=variables[0]+'_'+str(cfg.numens)+'ens_'+cfg.season+'_'+cfg.area+'_'+cfg.kind
    print('The name of the output files will be <variable>_{0}.txt'.format(name_outputs))
 
    ####################### PRECOMPUTATION #######################
    #____________run ens_anom as a module
    ens_anom(model_filelist,out_dir,name_outputs,variables[0],cfg.numens,cfg.season,cfg.area,cfg.extreme)

    ####################### EOF AND K-MEANS ANALYSES #######################
    #____________run ens_eof_kmeans as a module
    ens_eof_kmeans(out_dir,name_outputs,cfg.numens,cfg.numpcs,cfg.perc,cfg.numclus)

    ####################### PLOT AND SAVE FIGURES ################################
    #____________run ens_plots as a module
    ens_plots(out_dir,name_outputs,cfg.numclus,cfg.field_to_plot)

    print('\n>>>>>>>>>>>> ENDED SUCCESSFULLY!! <<<<<<<<<<<<\n')
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

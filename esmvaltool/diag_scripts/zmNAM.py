"""
;;#############################################################################
;; Zonal mean Northern Annular Mode Diagnostics
;; Author: Federico Serva (ISAC-CNR, Italy)
;; Copernicus C3S 34a lot 2 (MAGIC)
;;#############################################################################
;; Description
;;    Evaluation of stratosphere-troposphere coupling
;;    based on EOF/PC analysis of the geopotential height field
;;    
;; Modification history
;;    20180510-A_serv_fe: Routines written.
;;
;;#############################################################################
"""

import yaml
import sys
#import cartopy.crs as ccrs
import matplotlib.pyplot as plt

import iris
#import iris.plot as iplt
#import iris.quickplot as qplt
import os
import logging

logger = logging.getLogger(__name__)

import warnings
if not sys.warnoptions:
    warnings.simplefilter("ignore")

def get_cfg():
    """Read diagnostic script configuration from settings.yml."""
    settings_file = sys.argv[1]
    with open(settings_file) as file:
        cfg = yaml.safe_load(file)
    return cfg


def get_input_files(cfg, index=0):
    """Get a dictionary with input files from metadata.yml files."""
    metadata_file = cfg['input_files'][index]
    with open(metadata_file) as file:
        metadata = yaml.safe_load(file)
    return metadata

def main():
    cfg = get_cfg()
    logger.setLevel(cfg['log_level'].upper())

    input_files = get_input_files(cfg)
    os.makedirs(cfg['plot_dir'])
    os.makedirs(cfg['work_dir'])
                            
    plot_dir=cfg['plot_dir']
    out_dir=cfg['work_dir']

    sys.path.append(cfg['path_diag_aux'])
    # Import full diagnostic routines
    from zmNAM_calc import zmNAM_calc
    from zmNAM_plot import zmNAM_plot
    from zmNAM_preproc import zmNAM_preproc

    for variable_name, filenames in input_files.items():
        logger.info("Processing variable %s", variable_name)

        filenames_cat=[]
        print('_____________________________\n{0} INPUT FILES:'.format(len(filenames)))
        for i in filenames:
            print(i)
            filenames_cat.append(i)
        print('_____________________________\n')

        #____________Building the name of output files

        os.chdir(out_dir)

        for ifile in filenames_cat:
            # Get model properties (project, name, run, ensemble member, period)
            ifile_props = ifile.rsplit('/',1)[1].rsplit('_',7)
            ifile_props = [ifile_props[0]+ifile_props[1]+\
                          ifile_props[3]+ifile_props[4]+\
                          ifile_props[7].replace('.nc','')] # RERUN!!!
            print(ifile_props); sys.exit()
            # zmNAM calculation
            zmNAM_preproc(ifile,[20,90])
            zmNAM_calc(out_dir+'/',out_dir+'/') 
            zmNAM_plot(out_dir+'/',plot_dir+'/')   


if __name__ == '__main__':
    iris.FUTURE.netcdf_promote = True
    logging.basicConfig(
        format="%(asctime)s [%(process)d] %(levelname)-8s "
               "%(name)s,%(lineno)s\t%(message)s"
    )
    main()


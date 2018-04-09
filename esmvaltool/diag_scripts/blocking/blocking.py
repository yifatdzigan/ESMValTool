# """Python example diagnostic."""
import logging
import yaml
import six
#
# import calendar
# import csv
# import os
import sys
# import glob
# import re
# import datetime
#
# import numpy as np
# import matplotlib
# from mpl_toolkits.basemap import Basemap
# from scipy import stats, math
#
import iris
# import iris.coords
# import iris.util
import iris.cube
# import iris.exceptions
import iris.analysis
# import iris.coord_categorisation
# from iris.experimental.equalise_cubes import equalise_attributes
# matplotlib.use('Agg')
# import matplotlib.pyplot as plt
#
# logger = logging.getLogger(__name__)
#
#

class SeaIceDrift():
    def __init__(self, settings_file):
        with open(settings_file) as file:
            self.cfg = yaml.safe_load(file)

        with open(self.cfg['input_files'][0]) as file:
            self.input_files = yaml.safe_load(file)
            for files in self.input_files.values():
                for attributes in files.values():
                    attributes['alias'] = '{0[model]}_{0[ensemble]}_' \
                                          '{0[start_year]}'.format(attributes)
        logging.basicConfig(format="%(asctime)s [%(process)d] %(levelname)-8s "
                                   "%(name)s,%(lineno)s\t%(message)s")
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(self.cfg['log_level'].upper())

    def compute(self):
        self.logger.info('Computing blocking')


if __name__ == '__main__':
    iris.FUTURE.netcdf_promote = True

    SeaIceDrift(settings_file = sys.argv[1]).compute()

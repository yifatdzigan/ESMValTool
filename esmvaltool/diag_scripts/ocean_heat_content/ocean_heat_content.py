# """Python example diagnostic."""
import logging
import yaml

import os
import sys
import six
import numpy as np

import iris
import iris.cube
import iris.analysis
import iris.util
from iris.analysis import SUM
from iris.coords import AuxCoord
from iris.cube import CubeList


import matplotlib.pyplot as plt

import iris.quickplot as qplt

class OceanHeatContent():
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
        self.write_plots = self.cfg['write_plots']
        self.write_netcdf = self.cfg['write_netcdf']

        self.min_depth = self.cfg.get('min_depth', 0.)
        self.max_depth = self.cfg.get('max_depth', np.inf)

    def compute(self):
        self.logger.info('Computing ocean heat content')

        for filename, attributes in six.iteritems(self.input_files['thetao']):
            thetao = iris.load_cube(filename,
                                    'sea_water_potential_temperature')
            self.logger.debug(thetao)
            depth = thetao.coord('depth')
            if not depth.has_bounds():
                depth.guess_bounds()

            depth_weight = np.zeros(depth.shape)
            for x in range(depth_weight.size):
                high = depth.bounds[x, 0]
                low = depth.bounds[x, 1]
                if low <= self.min_depth:
                    continue
                if high >= self.max_depth:
                    continue
                if low > self.max_depth:
                    low = self.max_depth
                if high < self.min_depth:
                    high = self.min_depth
                size = low - high
                if size < 0:
                    size = 0
                depth_weight[x] = size
            thetao.add_aux_coord(AuxCoord(var_name='depth_weight',
                                         points=depth_weight),
                                 thetao.coord_dims(depth))

            thetao = thetao.extract(iris.Constraint(depth_weight=lambda x: x > 0))
            depth_weight = thetao.coord('depth_weight').points

            ohc2d = CubeList()
            final_weight = None
            self.logger.debug('Starting computation...')
            for slice in thetao.slices_over('time'):
                if final_weight is None:
                    index = slice.coord_dims('depth')[0]
                    depth_weight *= 4000 * 1020
                    final_weight = iris.util.broadcast_to_shape(depth_weight,
                                                                slice.shape,
                                                                (index,))
                ohc2d.append(slice.collapsed('depth', SUM,
                                             weights=final_weight))
            self.logger.debug('Merging results...')
            ohc2d = ohc2d.merge_cube()
            ohc2d.units = 'J m^-2'
            ohc2d.var_name = 'ohc'
            ohc2d.long_name = 'Ocean Heat Content per area unit'
            self.logger.debug(ohc2d)
            if self.write_plots:
                qplt.contourf(ohc2d, 25)
                plt.gca().coastlines()
                plot_filename = 'ohc2D_{0[project]}_{0[model]}_{0[ensemble]}' \
                                '.{1}'.format(attributes, self.cfg['output_file_type'])
                plt.savefig(os.path.join(self.cfg['plot_dir'], plot_filename))

            if self.write_netcdf:
                iris.save(ohc2d, os.path.join(self.cfg['plot_dir'],
                                              os.path.basename(filename).replace('thetao', 'ohc')))

if __name__ == '__main__':
    OceanHeatContent(settings_file = sys.argv[1]).compute()

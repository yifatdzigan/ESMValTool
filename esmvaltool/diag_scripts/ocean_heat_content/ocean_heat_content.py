"""Ocean heat content diagnostic"""

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
import iris.quickplot as qplt

import matplotlib.pyplot as plt

from esmvaltool.diag_scripts.diagnostic import Diagnostic


class OceanHeatContent(Diagnostic):
    """
    Ocean heat content diagnostic

    Allowed parameters:
    - min_depth: float=0
    - max_depth: float=np.inf

    Parameters
    ----------
    settings_file: str
        Path to the settings file

    """

    def __init__(self, settings_file):

        super().__init__(settings_file)

        self.min_depth = self.cfg.get('min_depth', 0.)
        self.max_depth = self.cfg.get('max_depth', np.inf)

    def compute(self):
        """Compute diagnostic"""
        self.logger.info('Computing ocean heat content')

        for filename, attributes in six.iteritems(self.input_files['thetao']):
            thetao = iris.load_cube(filename,
                                    'sea_water_potential_temperature')
            self.logger.debug(thetao)
            self._compute_depth_weights(thetao)

            has_weight = iris.Constraint(depth_weight=lambda x: x > 0)
            thetao = thetao.extract(has_weight)
            depth_weight = thetao.coord('depth_weight').points

            ohc2d = CubeList()
            final_weight = None
            self.logger.debug('Starting computation...')
            for time_slice in thetao.slices_over('time'):
                if final_weight is None:
                    index = time_slice.coord_dims('depth')[0]
                    depth_weight *= 4000 * 1020
                    final_weight = \
                        iris.util.broadcast_to_shape(depth_weight,
                                                     time_slice.shape,
                                                     (index,))
                ohc2d.append(time_slice.collapsed('depth', SUM,
                                                  weights=final_weight))
            self.logger.debug('Merging results...')
            ohc2d = ohc2d.merge_cube()
            ohc2d.units = 'J m^-2'
            ohc2d.var_name = 'ohc'
            ohc2d.long_name = 'Ocean Heat Content per area unit'
            self.logger.debug(ohc2d)

            self._plot(ohc2d, attributes)
            self._save_netcdf(ohc2d, filename)

    def _compute_depth_weights(self, thetao):
        depth = thetao.coord('depth')
        if not depth.has_bounds():
            depth.guess_bounds()
        depth_weight = np.zeros(depth.shape)
        for current_depth in range(depth_weight.size):
            high = depth.bounds[current_depth, 0]
            low = depth.bounds[current_depth, 1]
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
            depth_weight[current_depth] = size
        thetao.add_aux_coord(AuxCoord(var_name='depth_weight',
                                      points=depth_weight),
                             thetao.coord_dims(depth))

    def _save_netcdf(self, ohc2d, filename):
        if self.write_netcdf:
            if not os.path.isdir(self.cfg['work_dir']):
                os.makedirs(self.cfg['work_dir'])
            new_filename = os.path.basename(filename).replace('thetao',
                                                              'ohc')
            netcdf_path = os.path.join(self.cfg['work_dir'],
                                       new_filename)
            iris.save(ohc2d, netcdf_path)

    def _plot(self, ohc2d, attributes):
        if self.write_plots:
            if not os.path.isdir(self.cfg['plot_dir']):
                os.makedirs(self.cfg['plot_dir'])
            for time_slice in ohc2d.slices_over('time'):
                qplt.pcolormesh(time_slice)
                datetime = time_slice.coord('time').cell(0).point
                time_str = datetime.strftime('%Y-%m')
                plot_filename = 'ohc2D_{0[project]}_{0[model]}_' \
                                '{0[ensemble]}_{1}' \
                                '.{2}'.format(attributes,
                                              time_str,
                                              self.cfg['output_file_type'])
                plot_path = os.path.join(self.cfg['plot_dir'],
                                         plot_filename)
                self.logger.debug(plot_path)
                plt.savefig(plot_path)
                plt.close()


if __name__ == '__main__':
    OceanHeatContent(settings_file=sys.argv[1]).compute()

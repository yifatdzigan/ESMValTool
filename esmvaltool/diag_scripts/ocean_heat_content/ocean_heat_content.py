"""Ocean heat content diagnostic"""

import os
import logging

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
import esmvaltool.diag_scripts.shared
import esmvaltool.diag_scripts.shared.names as n

logger = logging.getLogger(os.path.basename(__file__))


class OceanHeatContent(object):
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

    def __init__(self, config):
        self.cfg = config
        self.datasets = esmvaltool.diag_scripts.shared.Datasets(self.cfg)
        self.variables = esmvaltool.diag_scripts.shared.Variables(self.cfg)
        self.min_depth = self.cfg.get('min_depth', 0.)
        self.max_depth = self.cfg.get('max_depth', np.inf)

    def compute(self):
        """Compute diagnostic"""
        logger.info('Computing ocean heat content')

        for filename in self.datasets:
            dataset_info = self.datasets.get_data(filename)
            thetao = iris.load_cube(filename,
                                    'sea_water_potential_temperature')
            self._compute_depth_weights(thetao)

            has_weight = iris.Constraint(depth_weight=lambda x: x > 0)
            thetao = thetao.extract(has_weight)
            depth_weight = thetao.coord('depth_weight').points

            ohc2d = CubeList()
            final_weight = None
            logger.debug('Starting computation...')
            for time_slice in thetao.slices_over('time'):
                if final_weight is None:
                    index = time_slice.coord_dims('depth')[0]
                    final_weight = \
                        iris.util.broadcast_to_shape(depth_weight,
                                                     time_slice.shape,
                                                     (index,))
                ohc = time_slice.collapsed('depth', SUM,
                                                  weights=final_weight)
                ohc.units = 'J m^-2'
                ohc.var_name = 'ohc'
                ohc.long_name = 'Ocean Heat Content per area unit'
                self._plot(ohc, dataset_info)
                ohc2d.append(ohc)
            logger.debug('Merging results...')

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
            depth_weight[current_depth] = size * 4000 * 1020
        thetao.add_aux_coord(AuxCoord(var_name='depth_weight',
                                      points=depth_weight),
                             thetao.coord_dims(depth))

    def _save_netcdf(self, ohc2d, filename):
        if self.cfg[n.WRITE_NETCDF]:
            ohc2d = ohc2d.merge_cube()
            new_filename = os.path.basename(filename).replace('thetao',
                                                              'ohc')
            netcdf_path = os.path.join(self.cfg[n.WORK_DIR],
                                       new_filename)
            iris.save(ohc2d, netcdf_path)

    def _plot(self, ohc2d, filename):
        iris.FUTURE.cell_datetime_objects = True
        if self.cfg[n.WRITE_PLOTS]:
            for time_slice in ohc2d.slices_over('time'):
                qplt.pcolormesh(time_slice)
                datetime = time_slice.coord('time').cell(0).point
                time_str = datetime.strftime('%Y-%m')
                plot_filename = 'ohc2D_{project}_{dataset}_' \
                                '{ensemble}_{time}' \
                                '.{out_type}'.format(
                    dataset=self.datasets.get_info(n.DATASET, filename),
                    project=self.datasets.get_info(n.PROJECT, filename),
                    ensemble=self.datasets.get_info(n.ENSEMBLE, filename),
                    time=time_str,
                    out_type=self.cfg[n.OUTPUT_FILE_TYPE])
                plot_path = os.path.join(self.cfg[n.PLOT_DIR],
                                         plot_filename)
                logger.debug(plot_path)

                plt.savefig(plot_path)
                plt.close()


if __name__ == '__main__':
    with esmvaltool.diag_scripts.shared.run_diagnostic() as config:
        OceanHeatContent(config).compute()

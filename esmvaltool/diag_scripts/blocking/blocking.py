"""Blocking diagnostic"""
import os
import sys
import six

import numpy as np
import iris
import iris.time
import iris.util
import iris.coord_categorisation
import iris.analysis
import iris.coords
import iris.quickplot
import matplotlib.pyplot
from matplotlib import colors

import esmvaltool.diag_scripts.shared
import esmvaltool.diag_scripts.shared.names as n


class Blocking(object):
    """
    Blocking diagnostic

    Allowed parameters:
    - central_latitude: float=60
    - span: float=20
    - offset: float=5
    - north_threshold: float=-10
    - south_threshold: float=0
    - months: list=[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    - max_color_scale: int=15
    - smoothing_window: int=3


    Parameters
    ----------
    settings_file: str
        Path to the settings file

    """

    def __init__(self, config):
        self.cfg = config
        self.datasets = esmvaltool.diag_scripts.shared.Datasets(self.cfg)
        self.variables = esmvaltool.diag_scripts.shared.Variables(self.cfg)

        self.central_latitude = self.cfg.get('central_latitude', 60.0)
        self.span = self.cfg.get('span', 20.0)
        self.offset = self.cfg.get('offset', 5.0)
        self.north_threshold = self.cfg.get('north_threshold', -10.0)
        self.south_threshold = self.cfg.get('south_threshold', 0.0)
        self.months = self.cfg.get('months', list(range(1, 13)))
        self.max_color_scale = self.cfg.get('max_color_scale', 15)
        self.smoothing_window = self.cfg.get('smoothing_window', 3)
        if self.smoothing_window % 2 == 0:
            raise ValueError('Smoothing should use an odd window '
                             'so the center of it is clear  ')

        self.min_latitude = self.central_latitude - self.span - self.offset
        self.max_latitude = self.central_latitude + self.span + self.offset

    def compute(self):
        """Compute blocking diagnostic"""
        self.logger.info('Computing blocking')
        for filename in self.datasets:
            zg500 = iris.load_cube(filename, 'geopotential_height')

            if len(set(self.months)) != 12:
                print('Extracting months ...')
                zg500 = zg500.extract(
                    iris.Constraint(month_number=self.months))
            iris.coord_categorisation.add_month(zg500, 'time')

            results = [self._blocking_1d(zg500, month) for month in
                       self.months]
            result = iris.cube.CubeList(results).merge_cube()
            if self.write_netcdf:
                new_filename = os.path.basename(filename).replace('zg',
                                                                  'blocking')
                netcdf_path = os.path.join(self.work_dir,
                                           new_filename)
                iris.save(result, netcdf_path)
            self._plot_result(result)

    def _plot_result(self, result):
        self.logger.debug(result.data)
        cmap = colors.LinearSegmentedColormap.from_list('mymap', (
            (1, 1, 1), (0.7, 0.1, 0.09)), N=self.max_color_scale)
        iris.quickplot.pcolormesh(result, cmap=cmap, vmin=0,
                                  vmax=self.max_color_scale)
        matplotlib.pyplot.axis('tight')
        matplotlib.pyplot.yticks(self.months)
        matplotlib.pyplot.show()

    def _blocking_1d(self, zg500, month):
        self.logger.info('Computing month %s...', month)
        zg500 = zg500.extract(iris.Constraint(month_number=month))

        blocking_index = None
        for displacement in [-self.offset, 0, self.offset]:
            central = self.central_latitude + displacement
            block = self._compute_blocking(zg500, central)
            if blocking_index is not None:
                blocking_index = np.logical_or(blocking_index, block)
            else:
                blocking_index = block

        blocking_frequency = np.sum(blocking_index, 0) / 10.0
        blocking_cube = iris.cube.Cube(
            self._smooth_over_longitude(blocking_frequency),
            var_name="block1d",
            units="Days per month",
            long_name="Blocking pattern",
            attributes=None,)

        blocking_cube.add_dim_coord(zg500.coord('longitude'), 0)
        month_coord = zg500.coord('month_number').copy(month)
        blocking_cube.add_aux_coord(month_coord)
        month_coord = zg500.coord('month').copy(zg500.coord('month').points[0])
        blocking_cube.add_aux_coord(month_coord)

        return blocking_cube

    def _smooth_over_longitude(self, cube):
        if self.smoothing_window == 1:
            return cube
        displacement = (self.smoothing_window - 1) // 2
        array = np.concatenate((cube[-displacement:],
                                cube,
                                cube[0:displacement]))
        ret = np.cumsum(array, dtype=float)
        ret[self.smoothing_window:] = \
            ret[self.smoothing_window:] - ret[:-self.smoothing_window]
        return ret[self.smoothing_window - 1:] / self.smoothing_window

    def _compute_blocking(self, zg500, central_latitude):
        latitude = zg500.coord('latitude')

        def _get_lat_cell(coord, latitude):
            return coord.cell(coord.nearest_neighbour_index(latitude))

        central_lat = _get_lat_cell(latitude, central_latitude)
        low_lat = _get_lat_cell(latitude, central_latitude - self.span)
        high_lat = _get_lat_cell(latitude, central_latitude + self.span)

        zg_low = zg500.extract(iris.Constraint(latitude=low_lat))
        zg_central = zg500.extract(iris.Constraint(latitude=central_lat))
        zg_high = zg500.extract(iris.Constraint(latitude=high_lat))

        north_gradient = (zg_high - zg_central) / \
                         (high_lat.point - central_lat.point)
        south_gradient = (zg_central - zg_low) / \
                         (central_lat.point - low_lat.point)

        return np.logical_and(south_gradient.data > self.south_threshold,
                              north_gradient.data < self.north_threshold)


if __name__ == '__main__':
    with esmvaltool.diag_scripts.shared.run_diagnostic() as config:
        Blocking(config).compute()

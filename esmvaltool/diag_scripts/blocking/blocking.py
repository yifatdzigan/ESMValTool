"""Blocking diagnostic"""
import logging
import yaml
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


class Blocking():
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

        self._read_config()

    def _read_config(self):
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
        self.logger.info('Computing blocking')
        print('Load data...')
        for filename, attributes in six.iteritems(self.input_files['zg']):
            zg500 = iris.load_cube(filename, 'geopotential_height')


            if len(set(self.months)) != 12:
                print('Extracting months ...')
                zg500 = zg500.extract(
                    iris.Constraint(month_number=self.months))
            iris.coord_categorisation.add_month(zg500, 'time')
            results = [self._blocking_1d(zg500, month) for month in
                       self.months]
            result = iris.cube.CubeList(results).merge_cube()
            self.logger.debug(result.data)
            cmap = colors.LinearSegmentedColormap.from_list('mymap', (
                (1, 1, 1), (0.7, 0.1, 0.09)), N=self.max_color_scale)
            iris.quickplot.pcolormesh(result, cmap=cmap, vmin=0,
                                      vmax=self.max_color_scale)

            matplotlib.pyplot.axis('tight')
            matplotlib.pyplot.yticks(self.months)

            matplotlib.pyplot.show()

    def _blocking_1d(self, zg500, month):
        print('Computing month {}...'.format(month))
        zg500 = zg500.extract(iris.Constraint(month_number=month))

        blocking_index = None
        for displacement in [-self.offset, 0, self.offset]:
            central = self.central_latitude + displacement
            block = self.calculate_blocking(zg500, central)
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
            attributes=None,
            )

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
        a = np.concatenate((cube[-displacement:], cube, cube[0:displacement]))
        ret = np.cumsum(a, dtype=float)
        ret[self.smoothing_window:] = ret[self.smoothing_window:] - \
                                      ret[:-self.smoothing_window]
        return ret[self.smoothing_window - 1:] / self.smoothing_window

    def calculate_blocking(self, zg500, central_latitude):
        latitude = zg500.coord('latitude')

        central_lat = self.get_lat_cell(latitude, central_latitude)
        low_lat = self.get_lat_cell(latitude, central_latitude - self.span)
        high_lat = self.get_lat_cell(latitude, central_latitude + self.span)

        zg_low = zg500.extract(iris.Constraint(latitude=low_lat))
        zg_central = zg500.extract(iris.Constraint(latitude=central_lat))
        zg_high = zg500.extract(iris.Constraint(latitude=high_lat))

        north_gradient = (zg_high - zg_central) / (
                high_lat.point - central_lat.point)
        south_gradient = (zg_central - zg_low) / (
                central_lat.point - low_lat.point)

        return np.logical_and(south_gradient.data > self.south_threshold,
                              north_gradient.data < self.north_threshold)

    def get_lat_cell(self, coord, latitude):
        return coord.cell(coord.nearest_neighbour_index(latitude))

if __name__ == '__main__':
    Blocking(settings_file=sys.argv[1]).compute()

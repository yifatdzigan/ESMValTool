"""Blocking diagnostic"""
import os
import logging
import itertools
import calendar

import numpy as np
import iris
import iris.time
import iris.util
import iris.coord_categorisation
import iris.analysis
import iris.coords
import iris.quickplot
import matplotlib.pyplot as plt
from matplotlib import colors

import esmvaltool.diag_scripts.shared
import esmvaltool.diag_scripts.shared.names as n

logger = logging.getLogger(os.path.basename(__file__))


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

    def __init__(self, conf):
        self.cfg = conf
        self.datasets = esmvaltool.diag_scripts.shared.Datasets(self.cfg)
        self.variables = esmvaltool.diag_scripts.shared.Variables(self.cfg)

        self.compute_1d = self.cfg.get('compute_1d', True)
        self.compute_2d = self.cfg.get('compute_2d', True)

        self.span = self.cfg.get('span', 20.0)
        self.north_threshold = self.cfg.get('north_threshold', -10.0)
        self.south_threshold = self.cfg.get('south_threshold', 0.0)
        self.smoothing_window = self.cfg.get('smoothing_window', 1)
        self.persistence = self.cfg.get('persistence', 1)

        # 1D configuration
        self.central_latitude = self.cfg.get('central_latitude', 60.0)
        self.offset = self.cfg.get('offset', 5.0)

        self.max_color_scale = self.cfg.get('max_color_scale', 15)

        if self.smoothing_window % 2 == 0:
            raise ValueError('Smoothing should use an odd window '
                             'so the center of it is clear  ')

        self.min_latitude = self.central_latitude - self.span - self.offset
        self.max_latitude = self.central_latitude + self.span + self.offset

    def compute(self):
        """Compute blocking diagnostic"""
        logger.info('Computing blocking')
        for filename in self.datasets:
            result = self._blocking(filename)
            self._blocking_1d(filename, result)
            self._blocking_2d(filename, result)

    def _blocking(self, filename):
        zg500 = iris.load_cube(filename, 'geopotential_height')
        iris.coord_categorisation.add_month(zg500, 'time')

        lat = zg500.coord('latitude')
        lat_max = np.max(lat.points)
        lat_min = np.min(lat.points)

        if self.compute_2d:
            latitudes = lat.points
        else:
            latitudes = (self.central_latitude - self.offset,
                         self.central_latitude,
                         self.central_latitude + self.offset)

        blocking = iris.cube.CubeList()
        for lat_point in latitudes:
            if lat_point + self.span > lat_max:
                continue
            if lat_point - self.span < lat_min:
                continue
            logger.debug('Computing blocking for lat %d', lat_point)
            blocking.append(self._compute_blocking(zg500, lat_point))

        blocking_cube = blocking.merge_cube()
        iris.coord_categorisation.add_year(blocking_cube, 'time')
        return blocking_cube

    def _blocking_1d(self, filename, blocking_index):
        if not self.compute_1d:
            return

        lat = blocking_index.coord('latitude')

        total_years = len(set(blocking_index.coord('year').points))

        blocking = None
        for displacement in [-self.offset, 0, self.offset]:
            central = self.central_latitude + displacement
            lat_value = lat.cell(lat.nearest_neighbour_index(central))
            lat_constraint = iris.Constraint(latitude=lat_value)
            block = blocking_index.extract(lat_constraint).data
            if blocking_index is not None:
                blocking = np.logical_or(blocking, block)
            else:
                blocking = block
        blocking_cube = iris.cube.Cube(
            blocking.astype(int),
            var_name="blocking",
            attributes=None)

        blocking_cube.add_dim_coord(blocking_index.coord('time'), (0,))
        blocking_cube.add_dim_coord(blocking_index.coord('longitude'), (1,))
        blocking_cube.add_aux_coord(iris.coords.AuxCoord.from_coord(
            blocking_index.coord('latitude').copy([self.central_latitude])))
        iris.coord_categorisation.add_month_number(blocking_cube, 'time')

        result = blocking_cube.aggregated_by('month_number',
                                             iris.analysis.SUM)
        result.remove_coord('time')
        iris.util.promote_aux_coord_to_dim_coord(result, 'month_number')

        result = self._smooth_over_longitude(result) / total_years
        result.units = 'days per month'
        result.var_name = 'blocking'
        result.long_name = 'Blocking 1D index'
        print(result)

        if self.cfg[n.WRITE_NETCDF]:
            new_filename = os.path.basename(filename).replace('zg',
                                                              'blocking1D')
            netcdf_path = os.path.join(self.cfg[n.WORK_DIR],
                                       new_filename)
            iris.save(result, target=netcdf_path, zlib=True)

        if self.cfg[n.WRITE_PLOTS]:
            iris.coord_categorisation.add_categorised_coord(
                result, 'month', result.coord('month_number'),
                lambda coord, x: calendar.month_abbr[x],
                units='no_unit')
            cmap = colors.LinearSegmentedColormap.from_list('mymap', (
                (1, 1, 1), (0.7, 0.1, 0.09)), N=self.max_color_scale)
            print(result)
            iris.quickplot.pcolormesh(result, coords=('longitude', 'month'),
                                      cmap=cmap, vmin=0,
                                      vmax=self.max_color_scale)
            plt.axis('tight')
            plt.yticks(range(result.coord('month').shape[0]),
                       result.coord('month').points)
            axes = plt.gca()
            axes.set_ylim((result.coord('month').shape[0] - 0.5, -0.5))
            plt.show()

            plot_path = self._get_plot_name(filename)
            # plt.savefig(plot_path)

    def _get_plot_name(self, filename):
        dataset = self.datasets.get_info(n.DATASET, filename)
        project = self.datasets.get_info(n.PROJECT, filename)
        ensemble = self.datasets.get_info(n.ENSEMBLE, filename)
        start = self.datasets.get_info(n.START_YEAR, filename)
        end = self.datasets.get_info(n.END_YEAR, filename)
        out_type = self.cfg[n.OUTPUT_FILE_TYPE]

        plot_filename = 'blocking1D_{project}_{dataset}_' \
                        '{ensemble}_{start}-{end}' \
                        '.{out_type}'.format(dataset=dataset,
                                             project=project,
                                             ensemble=ensemble,
                                             start=start,
                                             end=end,
                                             out_type=out_type)

        plot_path = os.path.join(self.cfg[n.PLOT_DIR],
                                 plot_filename)
        return plot_path

    def _smooth_over_longitude(self, cube):
        if self.smoothing_window == 1:
            return cube
        logger.debug('Smoothing...')
        for month_slice in cube.slices_over('month_number'):
            smooth = np.zeros_like(month_slice.data)
            size = month_slice.shape[0]
            window = self.smoothing_window // 2
            for i in range(0, window):
                win = np.concatenate((month_slice.data[0: i + window],
                                      month_slice.data[- window + i:]))
                smooth[i] = np.mean(win)

            for i in range(window, size - window):
                smooth[i] = np.mean(month_slice.data[i - window: i + window])

            for i in range(size - window, size):
                win = np.concatenate((
                    month_slice.data[i - window:],
                    month_slice.data[0: i + window - size + 1]))
                smooth[i] = np.mean(win)
            month_slice.data[...] = smooth[...]
        logger.debug('Smoothing finished!')
        return cube

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

        blocking_index = np.logical_and(
            south_gradient.data > self.south_threshold,
            north_gradient.data < self.north_threshold
        )

        blocking_cube = iris.cube.Cube(
            blocking_index,
            var_name="blocking",
            units="Days per month",
            long_name="Blocking pattern",
            attributes=None, )
        blocking_cube.add_aux_coord(zg500.coord('month_number'), (0,))
        blocking_cube.add_aux_coord(iris.coords.AuxCoord.from_coord(
            zg500.coord('latitude').copy([central_latitude])))
        blocking_cube.add_dim_coord(zg500.coord('time'), (0,))
        blocking_cube.add_dim_coord(zg500.coord('longitude'), (1,))

        if self.persistence > 1:
            self._apply_persistence(blocking_cube)
        return blocking_cube

    def _apply_persistence(self, blocking_cube):
        for lon_slice in blocking_cube.slices_over('longitude'):
            grouped = ((k, sum(1 for _ in g))
                       for k, g in itertools.groupby(lon_slice.data))
            index = 0
            for value, length in grouped:
                if value and length < self.persistence:
                    lon_slice.data[index: index + length] = False
                index += length
        return blocking_cube

    def _blocking_2d(self, filename, blocking_index):
        if not self.compute_2d:
            return
        total_years = len(set(blocking_index.coord('year').points))
        blocking_index = blocking_index.aggregated_by(
            'month_number', iris.analysis.SUM) / total_years

        blocking_index.long_name = 'Blocking index'
        blocking_index.units = 'Days per month'

        if self.cfg[n.WRITE_NETCDF]:
            new_filename = os.path.basename(filename).replace('zg',
                                                              'blocking')
            netcdf_path = os.path.join(self.cfg[n.WORK_DIR],
                                       new_filename)
            iris.save(blocking_index, netcdf_path, zlib=True)

        if self.cfg[n.WRITE_PLOTS]:
            for month_slice in blocking_index.slices_over('month_number'):
                cmap = colors.LinearSegmentedColormap.from_list('mymap', (
                    (1, 1, 1), (0.7, 0.1, 0.09)), N=self.max_color_scale)
                iris.quickplot.pcolormesh(
                    month_slice,
                    coords=('longitude', 'latitude'),
                    cmap=cmap, vmin=0, vmax=self.max_color_scale
                )
                plot_path = self._get_plot_name_2d(
                    filename,
                    month_slice.coord('month_number').points[0]
                )
                plt.gca().set_aspect(1.5, 'box')
                plt.gca().coastlines()
                plt.savefig(plot_path, bbox_inches='tight', pad_inches=0.2)
                plt.close()

    def _get_plot_name_2d(self, filename, month):
        dataset = self.datasets.get_info(n.DATASET, filename)
        project = self.datasets.get_info(n.PROJECT, filename)
        ensemble = self.datasets.get_info(n.ENSEMBLE, filename)
        start = self.datasets.get_info(n.START_YEAR, filename)
        end = self.datasets.get_info(n.END_YEAR, filename)
        out_type = self.cfg[n.OUTPUT_FILE_TYPE]
        month = calendar.month_abbr[month]

        plot_filename = 'blocking2D_{month}_{project}_{dataset}_' \
                        '{ensemble}_{start}-{end}' \
                        '.{out_type}'.format(dataset=dataset,
                                             project=project,
                                             ensemble=ensemble,
                                             start=start,
                                             end=end,
                                             out_type=out_type,
                                             month=month)

        plot_path = os.path.join(self.cfg[n.PLOT_DIR],
                                 plot_filename)
        return plot_path


def main():
    with esmvaltool.diag_scripts.shared.run_diagnostic() as config:
        Blocking(config).compute()


if __name__ == '__main__':
    main()

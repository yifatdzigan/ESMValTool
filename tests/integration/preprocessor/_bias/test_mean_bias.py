"""
Integration tests for the :func:`esmvaltool.preprocessor._bias._mean_bias`
function.

"""

from __future__ import absolute_import, division, print_function

import numpy as np
from iris.cube import Cube
from iris.coords import DimCoord
from iris.coord_categorisation import add_day_of_year, add_month_number, \
     add_season, add_year, add_season_number


import tests
from esmvaltool.preprocessor._bias import _mean_bias


class Test(tests.Test):
    def setUp(self):
        cube = Cube(np.ones(730), long_name='test', units='1.0')
        cube.add_dim_coord(
            DimCoord(
                np.arange(0, 730),
                standard_name='time',
                units='days since 1-1-2001'
            ),
            0,
        )
        add_day_of_year(cube, 'time')
        add_month_number(cube, 'time')
        add_season(cube, 'time')
        add_season_number(cube, 'time')
        add_year(cube, 'time')
        self.cube = cube

    def test_bad_period(self):
        with self.assertRaises(ValueError):
            _mean_bias(self.cube, 'Badperiod')

    def test_day(self):
        self.cube.data *= self.cube.coord('day_of_year').points
        assert not np.allclose(self.cube.data, np.zeros(730))
        result = _mean_bias(self.cube, 'day')
        assert np.allclose(result.data, np.zeros(730))

    def test_month(self):
        self.cube.data *= self.cube.coord('month_number').points
        assert not np.allclose(self.cube.data, np.zeros(730))
        result = _mean_bias(self.cube, 'month')
        assert np.allclose(result.data, np.zeros(730))

    def test_season(self):
        self.cube.data *= self.cube.coord('season_number').points
        assert not np.allclose(self.cube.data, np.zeros(730))
        result = _mean_bias(self.cube, 'season')
        assert np.allclose(result.data, np.zeros(730))


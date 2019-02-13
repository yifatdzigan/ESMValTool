"""Bias correction on cubes.

Allows for selecting data subsets using certain time bounds;
constructing seasonal and area averages.
"""
import logging

import iris
from iris.cube import CubeList
from iris.analysis import MEAN
from iris.coord_categorisation import add_year

logger = logging.getLogger(__name__)


def bias_correction(cube, method, options):
    """Remove bias from cube

    Parameters
    ----------
        cube: iris.cube.Cube
            input cube.
        method: str
            method to use
        options: dict
            start month

    Returns
    -------
    iris.cube.Cube
        Bias corrected cube.

    """
    if method.lower() == 'mean':
        corrected_cube = _mean_bias(cube, **options)
    else:
        raise ValueError('Unsuportted bias correction method "%s"' % method)


    return corrected_cube

def _mean_bias(cube, period):
    period_coordinates = {
        'day': 'day_of_year',
        'month': 'month_number',
        'season': 'season',
    }
    try:
        coordinate = period_coordinates[period]
    except KeyError:
        raise ValueError(
            'Period %s not supported in mean bias correction' % period
        )
    mean = cube.aggregated_by(coordinate, MEAN)
    corrected = CubeList()
    for mean_slice in mean.slices_over(coordinate):
        value = mean_slice.coord(coordinate).points[0]
        cube_slice = cube.extract(
            iris.Constraint(**{coordinate: value})
        )
        fixed = cube_slice - mean_slice
        fixed.metadata = cube_slice.metadata
        try:
            for fix_slice in fixed.slices_over('time'):
                fix_slice.remove_coord('year')
                corrected.append(fix_slice)
        except iris.exceptions.CoordinateNotFoundError:
            corrected.append(fixed)

    corrected = corrected.merge_cube()
    corrected.metadata = cube.metadata
    add_year(corrected, 'time')
    return corrected

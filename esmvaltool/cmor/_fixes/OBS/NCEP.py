"""Fixes for NCEP-NCAR"""

from iris import Constraint
from iris.cube import CubeList

from ..fix import Fix


class zg(Fix):
    """Class to fix clisccp"""

    def fix_metadata(self, cube):
        slices = CubeList(reversed(
            [lat_slice for lat_slice in cube.slices_over('latitude')]
        ))
        cube = slices.merge_cube()
        lev_coord = cube.coord('Level')
        lev_coord.var_name = 'plev'
        lev_coord.standard_name = 'air_pressure'
        print('Returning cube ....')
        print(cube)
        return cube

"""Fixes for NCEP-NCAR"""

from iris import Constraint

from ..fix import Fix


class zg(Fix):
    """Class to fix clisccp"""

    def fix_raw_cubes(self, cubes):
        zg_constraint = Constraint(cube_func=(lambda c: c.var_name == 'zg'))
        zg_cube = cubes.extract(zg_constraint)[0]
        zg_cube.standard_name = 'geopotential_height'
        return cubes

    def fix_metadata(self, cube):
        lev_coord = cube.coord('Level')
        lev_coord.var_name = 'plev'
        lev_coord.standard_name = 'air_pressure'
        cube = cube.intersection(latitude=(-90, 90))
        return cube

"""Fixes for EC-Earth3-HR PRIMAVERA project data"""
import iris.coords
from ..fix import Fix


class allvars(Fix):
    """Fixes common to all variables"""

    def fix_metadata(self, cube):
        """
        Fixes cube metadata

        Parameters
        ----------
        cube: Cube
            Cube to fix

        Returns
        -------
        Cube:
            Fixed cube. It is the same instance that was received
        """
        latitude = cube.coord('latitude')
        latitude.var_name = 'lat'

        longitude = cube.coord('longitude')
        longitude.var_name = 'lon'
        return cube


class siconc(Fix):
    """Fixes common to all variables"""

    def fix_metadata(self, cube):
        """
        Fixes cube metadata

        Add typesi coordinate

        Parameters
        ----------
        cube: Cube
            Cube to fix

        Returns
        -------
        Cube:
            Fixed cube. It is the same instance that was received
        """
        cube.add_aux_coord(iris.coords.AuxCoord(['sea_ice'],
                                                standard_name='area_type',
                                                var_name='type',
                                                long_name='Sea Ice area type'))
        return cube

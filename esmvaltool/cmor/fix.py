"""
Apply automatic fixes for known errors in cmorized data

All functions in this module will work even if no fixes are available
for the given dataset. Therefore is recommended to apply them to all
variables to be sure that all known errors are
fixed.

"""
from ._fixes.fix import Fix
from .check import _get_cmor_checker


def fix_file(file, short_name, project, dataset, output_dir):
    """
    Fix files before ESMValTool can load them

    This fixes are only for issues that prevent iris from loading the cube or
    that cannot be fixed after the cube is loaded.

    Original files are not overwritten.

    Parameters
    ----------
    file: str
        Path to the original file
    short_name: str
        Variable's short name
    project: str
    dataset:str
    output_dir: str
        Output directory for fixed files

    Returns
    -------
    str:
        Path to the fixed file

    """
    for fix in Fix.get_fixes(
            project=project, dataset=dataset, variable=short_name):
        file = fix.fix_file(file, output_dir)
    return file


def fix_metadata(cube, short_name, project, dataset, cmor_table=None,
                 mip=None):
    """
    Fix cube metadata if fixes are required and check it anyway

    This method collects all the relevant fixes for a given variable, applies
    them and checks the resulting cube (or the original if no fixes were
    needed) metadata to ensure that it complies with the standards of its
    project CMOR tables.

    Parameters
    ----------
    cube: iris.cube.Cube
        Cube to fix
    short_name; str
        Variable's short name
    project: str

    dataset: str

    cmor_table: str, optional
        CMOR tables to use for the check, if available

    mip: str, optional
        Variable's MIP, if available

    Returns
    -------
    iris.cube.Cube:
        Fixed and checked cube

    Raises
    ------
    CMORCheckError:
        If the checker detects errors in the metadata that it can not fix.

    """
    for fix in Fix.get_fixes(
            project=project, dataset=dataset, variable=short_name):
        cube = fix.fix_metadata(cube)
    if cmor_table and mip:
        checker = _get_cmor_checker(
            table=cmor_table,
            mip=mip,
            short_name=short_name,
            fail_on_error=False,
            automatic_fixes=True)
        checker(cube).check_metadata()
    return cube


def fix_data(cube, short_name, project, dataset, cmor_table=None, mip=None):
    """
    Fix cube data if fixes add present and check it anyway.

    This method assumes that metadata is already fixed and checked.

    This method collects all the relevant fixes for a given variable, applies
    them and checks resulting cube (or the original if no fixes were
    needed) metadata to ensure that it complies with the standards of its
    project CMOR tables.

    Parameters
    ----------
    cube: iris.cube.Cube
        Cube to fix
    short_name; str
        Variable's short name
    project: str

    dataset: str

    cmor_table: str, optional
        CMOR tables to use for the check, if available

    mip: str, optional
        Variable's MIP, if available

    Returns
    -------
    iris.cube.Cube:
        Fixed and checked cube

    Raises
    ------
    CMORCheckError:
        If the checker detects errors in the data that it can not fix.

    """
    for fix in Fix.get_fixes(
            project=project, dataset=dataset, variable=short_name):
        cube = fix.fix_data(cube)
    if cmor_table and mip:
        checker = _get_cmor_checker(
            table=cmor_table,
            mip=mip,
            short_name=short_name,
            fail_on_error=False,
            automatic_fixes=True)
        checker(cube).check_data()
    return cube

"""Code that is shared between multiple diagnostic scripts."""
from . import names, plot
from ._base import (ProvenanceLogger, extract_variables, get_cfg,
                    get_diagnostic_filename, get_plot_filename, group_metadata,
                    run_diagnostic, select_metadata, sorted_group_metadata,
                    sorted_metadata, variables_available)
from ._diag import Datasets, Variable, Variables
from ._io import (get_all_ancestor_files, get_ancestor_file,
                  metadata_to_netcdf, netcdf_to_metadata, save_1d_data,
                  save_iris_cube, save_scalar_data, unify_1d_cubes)
from ._iris_helpers import (check_coordinate, iris_project_constraint,
                            match_dataset_coordinates)
from ._validation import apply_supermeans, get_control_exper_obs

__all__ = [
    # Main entry point for diagnostics
    'run_diagnostic',
    # Define output filenames
    'get_diagnostic_filename',
    'get_plot_filename',
    # Log provenance
    'ProvenanceLogger',
    # Select and sort input metadata
    'select_metadata',
    'sorted_metadata',
    'group_metadata',
    'sorted_group_metadata',
    'extract_variables',
    'variables_available',
    'names',
    'Variable',
    'Variables',
    'Datasets',
    'get_cfg',
    # IO
    'get_all_ancestor_files',
    'get_ancestor_file',
    'metadata_to_netcdf',
    'netcdf_to_metadata',
    'save_1d_data',
    'save_iris_cube',
    'save_scalar_data',
    # Iris helpers
    'check_coordinate',
    'iris_project_constraint',
    'match_dataset_coordinates',
    'unify_1d_cubes',
    # Plotting module
    'plot',
    # Validation module
    'get_control_exper_obs',
    'apply_supermeans',
]

"""wrapper diagnostic for the NCAR CVDP (p)ackage.  """
import logging
import os
import re
import subprocess
from pprint import pformat

from esmvaltool.diag_scripts.shared import (group_metadata, run_diagnostic,
                                            select_metadata, sorted_metadata)
from esmvaltool.diag_scripts.shared.plot import quickplot
from esmvaltool._task import DiagnosticError

logger = logging.getLogger(os.path.basename(__file__))


def main(cfg):
    """Main function."""
    setup_driver(cfg)
    setup_namelist(cfg)
    subprocess.run(["ncl", "driver.ncl"], cwd=os.path.join(cfg['work_dir']))


def setup_driver(cfg):
    """Setup the driver.ncl file of the cvdp package."""
    cvdp_root = os.path.join(os.path.dirname(__file__), '../../cvdp')
    if not os.path.isdir(cvdp_root):
        raise DiagnosticError("CVDP is not available.")

    SETTINGS = {
        'outdir': "{0}/".format(cfg['work_dir']),
        'obs': 'False',
        'zp': os.path.join(cvdp_root, "ncl_scripts/"),
        'run_style': 'serial',
        'webpage_title': 'CVDP run via ESMValTool'
    }
    SETTINGS['output_data'] = "True" if _nco_available() else "False"

    def _update_settings(line):

        for k, v in SETTINGS.items():
            pattern = r'\s*{0}\s*=.*\n'.format(k)
            s = re.findall(pattern, line)
            if s == []:
                continue
            return re.sub(r'".+?"', '"{0}"'.format(v), s[0], count=1)

        return line

    content = []
    driver = os.path.join(cvdp_root, "driver.ncl")

    with open(driver, 'r') as f:
        for line in f:
            content.append(_update_settings(line))

    new_driver = os.path.join(cfg['work_dir'], "driver.ncl")

    with open(new_driver, 'w') as f:
        f.write("".join(content))


def create_link(cfg, p):
    """Create link for the input file that matches the naming convention
    of the cvdp package. Return the path to the link.

    cfg: configuration dict
    p: path to infile

    """

    def _create_link_name(p):
        import re
        h, t = os.path.split(p)
        s = re.search(r'[0-9]{4}-[0-9]{4}', t).group(0)
        return t.replace(s, "{0}01-{1}12".format(*s.split('-')))

    if not os.path.isdir(p):
        #raise DiagnosticError("Path {0} does not exist".format(p))
        logger.debug("Path %s does not exist! Continue", p)

    lnk_dir = os.path.join(cfg['work_dir'], "links")

    if not os.path.isdir(lnk_dir):
        os.mkdir(lnk_dir)

    link = os.path.join(lnk_dir, _create_link_name(p))
    os.symlink(p, link)

    return link


def setup_namelist(cfg):
    """Setup the namelist file of the cvdp package."""
    input_data = cfg['input_data'].values()
    selection = select_metadata(input_data, project='CMIP5')
    grouped_selection = group_metadata(selection, 'dataset')

    content = []
    for k, v in grouped_selection.items():
        links = [create_link(cfg, item["filename"]) for item in v]
        head, tail = os.path.split(links[0])
        head, tail = os.path.split(head)
        tail = "_".join(tail.split('_')[:-1])
        ppath = "{}*/".format(os.path.join(head, tail))
        content.append("{0} | {1} | {2} | {3}\n".format(
            k, ppath, v[0]["start_year"], v[0]["end_year"]))

    namelist = os.path.join(cfg['work_dir'], "namelist")

    with open(namelist, 'w') as f:
        f.write("\n".join(content))


def log_functions(func):
    """Decorater for check functions."""

    def inner():
        ret = func()
        logger.debug("Function %s returns %s", func.__name__, str(ret))
        return ret

    return inner


@log_functions
def _nco_available():
    """Check if nco is available."""
    try:
        retcode = subprocess.call("which ncks", shell=True)
        if retcode < 0:
            return False
        else:
            return True
    except OSError as e:
        return False


if __name__ == '__main__':

    with run_diagnostic() as config:
        main(config)
"""Blocking diagnostic"""
import logging
import yaml


class Diagnostic():
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
        self.write_plots = self.cfg['write_plots']
        self.write_netcdf = self.cfg['write_netcdf']
        self.title = self.cfg['title']
        self.plot_dir = self.cfg['plot_dir']
        self.run_dir = self.cfg['run_dir']
        self.work_dir = self.cfg['work_dir']
        self.version = self.cfg['run_dir']
        self.output_file_type = self.cfg['output_file_type']

    def compute(self):
        raise NotImplementedError('Diagnostics must implement the '
                                  'compute method')

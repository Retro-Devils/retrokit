from __future__ import annotations

from romkit.systems.base import BaseSystem
from romkit.systems.pc.metadata import ExodosMetadata

import configparser
import json
import subprocess
import zipfile
from pathlib import Path

class PCSystem(BaseSystem):
    name = 'pc'

    supported_metadata = BaseSystem.supported_metadata + [
        ExodosMetadata,
    ]

    APP_ROOT = Path(__file__).parent.resolve().joinpath('../../../..').resolve()
    CONFIG_ARCHIVE = f'{APP_ROOT}/cache/exodos/dosbox-cfg.zip'

    def install_machine(self, machine: Machine) -> bool:
        success = super().install_machine(machine)

        if success:
            self.install_config(machine)
            self.fix_paths(machine)

        return success

    # Installs the dosbox configuration file required to run the machine.
    # Note that this will install the default configuration provided by eXoDOS.
    def install_config(self, machine: Machine) -> None:
        with zipfile.ZipFile(self.CONFIG_ARCHIVE, 'r') as conf_zip:
            exodos_name = machine.sourcefile
            machine_dir = str(machine.resource.target_path.path)

            conf_file = conf_zip.getinfo(f'{exodos_name}/dosbox.conf')
            conf_file.filename = 'dosbox.conf'
            conf_zip.extract(conf_file, machine_dir)

            if f'{exodos_name}/mapper.map' in conf_zip.namelist():
                mapper_file = conf_zip.getinfo(f'{exodos_name}/mapper.map')
                mapper_file.filename = 'mapper.map'
                conf_zip.extract(zip_info, mapper_file)

            self.setup_config(machine)

    # Updates the dosbox configuration with overall and game-specific overrides provided
    def setup_config(self, machine: Machine) -> None:
        machine_dir = machine.resource.target_path.path
        config_path = machine_dir.joinpath('dosbox.conf')

        config = configparser.ConfigParser()
        config.optionxform = str
        config.read(config_path)
        overwrite = False

        # Migrate predefined config to one suitable for the current emulator
        migration_path_template = self.config['roms']['files']['conf'].get('migration')
        if migration_path_template:
            migration_path = Path(migration_path_template.format(emulator=machine.emulator))
            if migration_path.exists():
                overwrite = True
                self.migrate_config(machine, config, migration_path)

        # Override with Machine-specific configurations
        overrides_template = self.config['roms']['files']['conf'].get('overrides')
        if overrides_template:
            overrides_path = Path(overrides_template.format(machine=machine.name))
            if overrides_path.exists():
                overwrite = True
                self.override_config(machine, config, overrides_path)

        # Overwrite the config if we made any changes
        with config_path.open('r') as config_file:
            config.write(config_file)

    # Migrate the configuration based on the given migration file
    def migrate_config(self, machine: Machine, config: configparser.ConfigParser, migration_path: str) -> None:
        migration = json.loads(migration_path)

        if 'blocklist' in migration:
            self.filter_config(config, migration['blocklist'], True)

        if 'allowlist' in migration:
            self.filter_config(config, migration['allowlist'], False)

        if 'translations' in migration:
            self.translate_config(config, migration['translations'])

    # Filters options from the given configuration
    def filter_config(self, config: configparser.ConfigParser, filters: dict, invert: bool) -> None:
        for section_name in config.sections():
            if section_name in filters:
                section_filters = filters[section_name]
                for option, value in config[section_name].items(raw=True):
                    if (option in section_filters) == invert:
                        config.remove_option(section_name, option)

    # Translates from one option to another (when the actual section / option names have
    # changed from what's in the predefined config files)
    def translate_config(self, config: configparser.ConfigPraser, translations: dict) -> None:
        for section_name in translations:
            if config.has_section(section):
                section = config[section_name]
                section_translations = translations[section_name]

                for option, value in section.items(raw=True):
                    if option in section_translations:
                        value = section.get(option, raw=True)
                        new_value_template = section_translations[option]
                        new_value = eval(f"f'{new_value_template}'")
                        config.set(section_name, option, new_value)

    # Override with configuration with Machine-specific settings
    def override_config(self, machine: Machine, config: configparser.ConfigParser, overrides_path: str) -> None:
        config.read(overrides_path)

    # Find two issues with paths:
    # * Switch windows-style slashes and replace them with linux-style
    # * Switch the root .eXoDOS reference to point to the directory that contains the games
    def fix_paths(self, machine: Machine) -> None:
        machine_dir = machine.resource.target_path.path
        files_to_fix = subprocess.run(['grep', '-lIR', ".\\eXoDOS", machine_dir], check=True, capture_output=True).stdout

        for filepath in files_to_fix.splitlines():
            subprocess.run(['sed', '-i', '/.\\\\eXoDOS/{s/\\\\/\\//g;}', filepath], check=True)

            exodos_dir = str(machine_dir.parent).replace(str(Path.home()), '')
            subprocess.run(['sed', '-i', f's|./eXoDOS|.{exodos_dir}|g', filepath], check=True)

    # Symlinks the configuration file so that it's visible in the frontend
    def enable_machine(self, machine: Machine, system_dir: SystemDir) -> None:
        config_file = machine.resource.target_path.path.joinpath('dosbox.conf')
        system_dir.symlink('conf', config_file, machine=machine.name)

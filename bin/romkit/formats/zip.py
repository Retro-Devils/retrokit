from romkit.formats import BaseFormat
from romkit.models import ROM

import contextlib
import logging
import os
import subprocess
import tempfile
import zipfile
from pathlib import Path

class ZipFormat(BaseFormat):
    name = 'zip'

    # Looks up the ROMs that have been installed locally for the given machine
    def find_local_roms(self, machine):
        return self._find_roms_in_filepath(machine, machine.filepath)

    # Merges ROMs from the source machine to the given target machine
    def merge(self, source, target, roms):
        source_roms = self._find_roms_in_filepath(source, source.source_filepath)
        source_zip = zipfile.ZipFile(source.source_filepath, 'r')

        target_roms_by_crc = {rom.crc: rom for rom in roms}

        with zipfile.ZipFile(target.filepath, 'a') as target_zip:
            for source_rom in source_roms:
                if source_rom in roms:
                    target_name = target_roms_by_crc[source_rom.crc].name
                    target_zip.writestr(target_name, source_zip.open(source_rom.name).read())

    # Removes a ROM from a machine
    def remove(self, machine, rom):
        # Until https://github.com/python/cpython/pull/19358 is merged...
        subprocess.check_call(['zip', '-d', machine.filename, rom.name])

    # Re-archives the file using TorrentZip for consistency with other services
    def finalize(self, machine):
        logging.info(f"Torrentzip'ing {machine.filepath}")

        # Run trrntzip in its own directory due to the log files it creates (with no control)
        with tempfile.TemporaryDirectory() as tmpdir:
            with self._pushd(tmpdir):
                subprocess.check_call(['trrntzip', machine.filepath], stdout=subprocess.DEVNULL)

    def _find_roms_in_filepath(self, machine, filepath):
        roms = set()

        if Path(filepath).exists():
            try:
                with zipfile.ZipFile(filepath, 'r') as zip_ref:
                    for zip_info in zip_ref.infolist():
                        name = zip_info.filename
                        crc = "%0.8X" % zip_info.CRC
                        roms.add(ROM(machine, name, crc))
            except zipfile.BadZipFile:
                # Ignore
                pass

        return roms

    @contextlib.contextmanager
    def _pushd(self, new_dir):
        previous_dir = os.getcwd()
        os.chdir(new_dir)
        try:
            yield
        finally:
            os.chdir(previous_dir)

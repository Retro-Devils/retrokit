from __future__ import annotations

from romkit.filters.base import ExactFilter

from typing import Set

# Filter on the input controls
class ControlFilter(ExactFilter):
    name = 'controls'

    def values(self, machine: Machine) -> Set[str]:
        return machine.controls

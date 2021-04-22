from __future__ import annotations

import logging

# Provides a base class for reducing the set of machines to install
class BaseFilter:
    name = None
    apply_to_favorites = False

    def __init__(self,
        filter_values: set = set(),
        invert: bool = False,
        log: bool = True,
        config: dict = {},
    ) -> None:
        self.filter_values = filter_values
        self.invert = invert
        self.log = log
        self.config = config

        self.download()
        self.load()

    # Does this filter allow the given machine?
    def allow(self, machine: Machine) -> bool:
        if self.invert:
            allowed = not self.match(machine)
        else:
            allowed = self.match(machine)

        if not allowed and self.log:
            logging.debug(f'[{machine.name}] Skip ({type(self).__name__})')

        return allowed

    # Downloads any relevant data needed to run the filter
    def download(self) -> None:
        pass

    # Loads all of the relevant data needed to run the filter
    def load(self) -> None:
        pass

    # Looks up the list of values associated with the machine
    def values(self, machine: Machine) -> set:
        raise NotImplementedError

    # Do the filter values match the given machine?
    def match(self, machine: Machine) -> bool:
        raise NotImplementedError


# Filter values must match exact values from the machine
class ExactFilter(BaseFilter):
    def match(self, machine: Machine) -> bool:
        machine_values = self.values(machine)
        return any(self.filter_values & machine_values)


# Filter values can be just a substring of values from the machine
class SubstringFilter(BaseFilter):
    def match(self, machine: Machine) -> bool:
        machine_values = self.values(machine)

        for machine_value in machine_values:
            if any(filter_value in machine_value for filter_value in self.filter_values):
                return True

        return False

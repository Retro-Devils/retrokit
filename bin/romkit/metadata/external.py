from __future__ import annotations

from romkit.resources.resource import ResourceTemplate
from romkit.util import Downloader

# Provides a base class for loading attributes external to a romset's DAT
class ExternalMetadata:
    name = None
    default_context = {}

    def __init__(self,
        config: dict = {},
        downloader: Downloader = Downloader.instance(),
    ) -> None:
        self.config = config
        self.downloader = downloader

        if 'source' in config:
            # If this has an external source attached to it, let's try to
            # install it
            self.resource_template = ResourceTemplate.from_json(
                config,
                downloader=downloader,
            )
            self.install()
        else:
            self.resource_template = None

        self.load()

    # Target destination for installing this attribute data
    @property
    def resource(self) -> Resource:
        if self.resource_template:
            # Avoid building context if we can since it may result in downloading
            # unnecessary external data
            resource = self.resource_template.render(**self.default_context)
            if resource.target_path.exists():
                return resource
            else:
                return self.resource_template.render(**self.context)

    # Path that the external data has been installed
    @property
    def install_path(self) -> Path:
        resource = self.resource
        if resource:
            return resource.target_path.path

    # Builds context for formatting urls
    @property
    def context(self) -> dict:
        return {}

    # Installs the externally-sourced data
    def install(self) -> None:
        self.resource.install()

    # Loads all of the relevant data needed to machine attributes
    def load(self) -> None:
        pass

    def update(self, machine: Machine) -> None:
        pass

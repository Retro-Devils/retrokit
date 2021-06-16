from romkit.filters import CategoryFilter as DefaultCategoryFilter
from romkit.systems import BaseSystem
from romkit.systems.arcade.emulator_set import ArcadeEmulatorSet
from romkit.systems.arcade.filters import LanguageFilter, CategoryFilter, RatingFilter

class ArcadeSystem(BaseSystem):
    name = 'arcade'
    supported_filters = (BaseSystem.supported_filters - set([DefaultCategoryFilter])) | set([
        LanguageFilter,
        CategoryFilter,
        RatingFilter,
    ])
    emulator_set_class = ArcadeEmulatorSet

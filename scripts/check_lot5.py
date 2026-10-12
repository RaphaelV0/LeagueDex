#!/usr/bin/env python3
"""Lightweight source invariants, not a replacement for Xcode builds or UI tests.

Run from any OS with: python3 scripts/check_lot5.py
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class LotFiveSourceChecks(unittest.TestCase):
    def test_image_cache_is_bounded_and_off_ui_thread(self):
        content = source("LeagueDex/Components/CachedAsyncImage.swift")
        for marker in (
            "private actor ImageDiskCache", "maxBytes",
            "lifetime", "SHA256.hash", "Task.detached",
            "ImageDecoder.thumbnail", "imageDimension(_ points:",
            "ImageMemoryCache.storage", "Task.isCancelled",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, content)

    def test_location_uses_one_shot_updates(self):
        content = source("LeagueDex/Utils/LocationManager.swift")
        self.assertIn("manager.requestLocation()", content)
        self.assertNotIn("manager.startUpdatingLocation()", content)
        self.assertIn("locationManagerDidChangeAuthorization", content)
        self.assertIn("didFailWithError", content)

    def test_accessibility_and_core_user_flows(self):
        champions = source("LeagueDex/Views/Champions/ChampionsView.swift")
        details = source("LeagueDex/Views/Champions/ChampionDetailView.swift")
        items = source("LeagueDex/Views/Items/ItemsView.swift")
        venues = source("LeagueDex/Views/VenuesMapView.swift")
        for marker in (".searchable", "selectRandomChampion()", ".onShake",
                       "showOnlyFavorites", "visibleChampions"):
            self.assertIn(marker, champions)
        for marker in ("viewModel.toggleFavorite", "viewModel.loadDetails",
                       "Slider(", "statAt(", "champion.skins",
                       "accessibilityLabel", "scalableHeroHeight"):
            self.assertIn(marker, details)
        for marker in (".searchable", "priceFilter", "visibleItems",
                       "PriceBox(", "accessibilityHint"):
            self.assertIn(marker, items)
        for marker in ("Map(position:", "requestLocation()", "locationError",
                       "maps.apple.com", "recenterOnUser"):
            self.assertIn(marker, venues)

    def test_privacy_reason_configured_for_both_build_types(self):
        project = source("LeagueDex.xcodeproj/project.pbxproj")
        self.assertEqual(
            project.count("INFOPLIST_KEY_NSLocationWhenInUseUsageDescription ="),
            2,
        )

    def test_reduced_motion_preferences_remain_supported(self):
        theme = source("LeagueDex/DesignSystem/LeagueTheme.swift")
        motion = source("LeagueDex/DesignSystem/LeagueMotion.swift")
        self.assertIn("accessibilityReduceMotion", theme)
        self.assertIn("accessibilityReduceMotion", motion)
        self.assertIn(".accessibilityAddTraits", theme)


if __name__ == "__main__":
    unittest.main(verbosity=2)

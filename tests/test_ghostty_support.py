#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text()


def test_default_config_mentions_ghostty():
    config = read("Shuttle/shuttle.default.json")
    assert "Ghostty.app" in config


def test_app_delegate_routes_ghostty_to_scripts():
    app_delegate = read("Shuttle/AppDelegate.m")
    assert 'rangeOfString: @"ghostty"' in app_delegate
    assert 'pathForResource:@"ghostty-new-window"' in app_delegate
    assert 'pathForResource:@"ghostty-current-window"' in app_delegate
    assert 'pathForResource:@"ghostty-new-tab-default"' in app_delegate


def test_shell_commands_are_not_treated_as_urls():
    app_delegate = read("Shuttle/AppDelegate.m")
    assert "if (url && [url scheme])" in app_delegate


def test_ghostty_scripts_are_bundled_resources():
    project = read("Shuttle.xcodeproj/project.pbxproj")
    for script in [
        "ghostty-new-window.scpt",
        "ghostty-current-window.scpt",
        "ghostty-new-tab-default.scpt",
    ]:
        assert script in project


def test_ghostty_has_apple_event_entitlement():
    entitlements = read("Shuttle/Shuttle.entitlements")
    assert "com.mitchellh.ghostty" in entitlements


def test_ghostty_source_scripts_use_applescript_api():
    for source in [
        "apple-scripts/ghostty/ghostty-new-window.applescript",
        "apple-scripts/ghostty/ghostty-current-window.applescript",
        "apple-scripts/ghostty/ghostty-new-tab-default.applescript",
    ]:
        script = read(source)
        assert 'tell application "/Applications/Ghostty.app"' in script
        assert "input text" in script
        assert 'send key "enter"' in script


if __name__ == "__main__":
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            value()

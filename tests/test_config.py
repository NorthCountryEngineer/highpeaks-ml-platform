"""Configuration file tests are disabled.

These tests require the ``pyyaml`` package, which is unavailable in the
current execution environment. To enable them, install dependencies from
``requirements.txt`` and provide the container with network access.
"""

# import yaml
# from pathlib import Path
#
#
# def test_settings_yaml_has_required_keys():
#     settings_path = Path(__file__).resolve().parents[1] / "config" / "settings.yaml"
#     with open(settings_path, 'r') as f:
#         data = yaml.safe_load(f)
#
#     assert "service" in data
#     assert "data" in data
#     assert "mlflow" in data
#     # check nested keys
#     assert "name" in data["service"]
#     assert "tracking_uri" in data["mlflow"]

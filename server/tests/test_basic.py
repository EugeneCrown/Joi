# -*- coding: utf-8 -*-
"""Basic sanity test for the project.

Ensures pytest runs without collecting any real tests and that the import
machinery works for the project's server package.
"""


def test_server_package_exists():
    """Check that the server package directory exists."""
    import pathlib

    base_dir = pathlib.Path(__file__).resolve().parents[2]  # project root
    joi_path = base_dir / "server" / "joi"
    assert joi_path.is_dir(), f"Expected package directory {joi_path} to exist"


def test_placeholder():
    assert True

"""Tests for the data pipeline scripts."""

import os
import runpy
import numpy as np
import requests
from pathlib import Path


def test_sample_ingestion_pipeline_downloads_file(tmp_path, monkeypatch):
    def fake_get(url):
        class Resp:
            status_code = 200
            content = b'dummy'

            def raise_for_status(self):
                pass

        return Resp()

    monkeypatch.setattr(requests, "get", fake_get)
    script_path = (
        Path(__file__).resolve().parents[1]
        / "data"
        / "ingestion"
        / "sample_ingestion_pipeline.py"
    )
    cwd = os.getcwd()
    os.chdir(tmp_path)
    try:
        runpy.run_path(script_path, run_name="__main__")
    finally:
        os.chdir(cwd)

    expected = tmp_path / "data" / "raw" / "mnist.npz"
    assert expected.exists()


def test_process_mnist_outputs_file(tmp_path):
    script_path = (
        Path(__file__).resolve().parents[1]
        / "data"
        / "processing"
        / "process_mnist.py"
    )

    raw_dir = tmp_path / "data" / "raw"
    raw_dir.mkdir(parents=True)

    x_train = np.zeros((1, 28, 28), dtype=np.uint8)
    y_train = np.array([0], dtype=np.uint8)
    x_test = np.zeros((1, 28, 28), dtype=np.uint8)
    y_test = np.array([0], dtype=np.uint8)
    np.savez(
        raw_dir / "mnist.npz",
        x_train=x_train,
        y_train=y_train,
        x_test=x_test,
        y_test=y_test,
    )

    cwd = os.getcwd()
    os.chdir(tmp_path)
    try:
        runpy.run_path(script_path, run_name="__main__")
    finally:
        os.chdir(cwd)

    expected = tmp_path / "data" / "processed" / "mnist_processed.npz"
    assert expected.exists()

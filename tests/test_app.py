"""Tests for the prediction endpoint."""

import numpy as np
import pytest
import mlflow.pyfunc


class DummyModel:
    def predict(self, data):
        return np.array([[0.0, 1.0]])


mlflow.pyfunc.load_model = lambda uri: DummyModel()

from app import app  # noqa: E402


@pytest.fixture
def client():
    app.testing = True
    return app.test_client()


def test_predict_endpoint(client):
    response = client.get('/predict')
    assert response.status_code == 200
    assert 'predicted_class' in response.get_json()

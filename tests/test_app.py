"""Tests for the prediction endpoint are commented out.

They require network access to download an MLflow model and depend on
packages that are not available in the execution environment (e.g.
``numpy`` and ``mlflow``). To enable these tests, configure the
container with network access and install the required dependencies as
listed in ``requirements.txt``.
"""

# import numpy as np
# import pytest
# import mlflow.pyfunc
#
#
# class DummyModel:
#     def predict(self, data):
#         return np.array([[0.0, 1.0]])
#
#
# mlflow.pyfunc.load_model = lambda uri: DummyModel()
#
# from app import app
#
# @pytest.fixture
# def client():
#     app.testing = True
#     return app.test_client()
#
# def test_predict_endpoint(client):
#     response = client.get('/predict')
#     assert response.status_code == 200
#     assert 'predicted_class' in response.get_json()

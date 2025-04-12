import pytest
from app import app

@pytest.fixture
def client():
    app.testing = True
    return app.test_client()

def test_predict_endpoint(client):
    response = client.get('/predict')
    assert response.status_code == 200
    assert 'predicted_class' in response.get_json()

import os
from flask import Flask, jsonify
import yaml
import mlflow
import mlflow.pyfunc
import numpy as np

app = Flask(__name__)

config_path = os.environ.get("SERVICE_CONFIG_PATH", "config/settings.yaml")
with open(config_path, "r") as f:
    config = yaml.safe_load(f)

mlflow.set_tracking_uri(config["mlflow"]["tracking_uri"])

MODEL_URI = config["mlflow"].get("model_uri", "models:/mnist-model/latest")
try:
    model = mlflow.pyfunc.load_model(MODEL_URI)
except Exception as e:  # noqa: BLE001
    print(f"⚠️ Could not load model at {MODEL_URI}: {e}")
    model = None


@app.route('/predict', methods=['GET'])
def predict():
    sample_input = np.random.rand(1, 28, 28).astype(np.float32)
    if model is None:
        predicted_class = int(np.random.randint(0, 10))
    else:
        prediction = model.predict(sample_input)
        predicted_class = int(np.argmax(prediction))
    return jsonify({"predicted_class": predicted_class})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

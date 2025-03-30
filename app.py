from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify(status='ok')

@app.route('/predict')
def predict():
    # Stub prediction logic (in a real app, this might call a model inference)
    result = {"prediction": 42}
    return jsonify(result)

if __name__ == '__main__':
    # Run the Flask app (accessible on all interfaces)
    app.run(host='0.0.0.0', port=5000)
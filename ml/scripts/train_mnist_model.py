# Basic MNIST training example with MLflow integration
import numpy as np
import mlflow
import tensorflow as tf
from tensorflow.keras import layers

data = np.load('data/processed/mnist_processed.npz')
x_train, y_train = data['x_train'], data['y_train']
x_test, y_test = data['x_test'], data['y_test']

model = tf.keras.Sequential([
    layers.Flatten(input_shape=(28, 28)),
    layers.Dense(128, activation='relu'),
    layers.Dense(10, activation='softmax')
])

model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

mlflow.set_tracking_uri("http://localhost:5001")
mlflow.set_experiment("mnist")

with mlflow.start_run():
    model.fit(x_train, y_train, epochs=5, validation_data=(x_test, y_test))
    test_loss, test_acc = model.evaluate(x_test, y_test)
    mlflow.log_metric("test_accuracy", test_acc)
    mlflow.tensorflow.log_model(model, "mnist-model")
    print(f"Test Accuracy: {test_acc}")

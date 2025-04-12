# Example script for processing MNIST dataset into training/validation splits
import numpy as np
import os

data = np.load('data/raw/mnist.npz')
x_train, y_train = data['x_train'], data['y_train']
x_test, y_test = data['x_test'], data['y_test']

# Normalize
x_train = x_train.astype('float32') / 255.
x_test = x_test.astype('float32') / 255.

# Save processed data
os.makedirs('data/processed', exist_ok=True)
np.savez('data/processed/mnist_processed.npz', x_train=x_train, y_train=y_train, x_test=x_test, y_test=y_test)
print("Processed MNIST dataset saved.")

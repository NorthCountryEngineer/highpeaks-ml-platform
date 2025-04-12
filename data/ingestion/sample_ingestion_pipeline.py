# Example script for dataset ingestion (e.g., MNIST)
import requests
import os

def download_file(url, target_path):
    response = requests.get(url)
    response.raise_for_status()
    with open(target_path, 'wb') as f:
        f.write(response.content)

if __name__ == "__main__":
    os.makedirs("data/raw", exist_ok=True)
    mnist_url = "https://storage.googleapis.com/tensorflow/tf-keras-datasets/mnist.npz"
    download_file(mnist_url, "data/raw/mnist.npz")
    print("MNIST dataset downloaded to data/raw/mnist.npz")

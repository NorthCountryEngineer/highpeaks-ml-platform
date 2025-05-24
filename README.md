# highpeaks-ml-platform

The **High Peaks ML Platform** service is the machine learning engine of the High Peaks AI platform. It is responsible for training models and serving predictions. In a full implementation, this service manages ML workflows, data pipelines, model versioning, and provides APIs for other services (and potentially the DevOps AI agent) to trigger training or retrieve prediction results.

Currently, the repository contains a basic web service illustrating the component structure, but it's now expanding to incorporate structured data ingestion, processing, model training, and experiment tracking, reflecting a more comprehensive ML platform setup.

## Repository Structure

```text
highpeaks-ml-platform/
├── README.md                    # Overview of the ML platform service
├── Dockerfile                   # Containerization for the ML service
├── requirements.txt             # Python dependencies (Flask, ML, data processing libraries)
├── app.py                       # Flask application simulating ML service endpoints
├── config/                      # Environment-specific configuration files
│   └── settings.yaml            # Settings for different deployments
├── data/                        # Data pipeline components
│   ├── ingestion/               # Scripts for data ingestion
│   ├── storage/                 # Scripts for data storage (e.g., MinIO/PostgreSQL)
│   └── processing/              # Data transformation and cleaning scripts
├── ml/                          # Machine learning components
│   ├── models/                  # Storage for trained models
│   ├── notebooks/               # Jupyter notebooks for exploration and analysis
│   └── scripts/                 # Training and inference scripts
├── infrastructure/              # Infrastructure resources
│   ├── docker-compose.yml       # Local stack definition
│   └── k8s/                     # Kubernetes deployment manifests
│       ├── namespace.yaml       # Kubernetes namespace definition
│       ├── deployment.yaml      # ML service Kubernetes deployment
│       ├── service.yaml         # ML service Kubernetes internal service
│       ├── mlflow.yaml          # MLflow deployment and service
│       └── storage.yaml         # MinIO/PostgreSQL deployment manifests
├── tests/                       # Test suites (unit and integration tests)
└── .github/
    └── workflows/
        └── ci.yml               # GitHub Actions workflow for CI/CD
```

## Configuration Overview

The application configuration resides in `config/settings.yaml`. Key sections
include:

* **`service`** – basic service metadata and runtime options such as `name`,
  `version`, `port`, and a `debug` flag.
* **`data.storage.minio`** – connection details for the object store used to
  persist training data and models. This includes the service `endpoint`, the
  target `bucket`, and access credentials.
* **`data.database.postgres`** – parameters for the PostgreSQL instance holding
  structured data. The block defines `host`, `port`, `dbname`, `user`, and
  `password`.
* **`mlflow`** – MLflow tracking server configuration with a `tracking_uri` and
  `experiment_name`.

By default the file is configured for local development, pointing at services
started by the Docker Compose stack. For a production deployment, update these
values to reference production endpoints and disable `debug`. Credentials should
be provided via environment variables or a secrets manager rather than in the
file.
## Development Setup

**Prerequisites:** Python 3.x (3.10 recommended), pip, Docker, Docker Compose, Kubernetes (`kubectl`, optionally `kind`).

1. **Setup a virtual environment (optional but recommended):**
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    ```

2. **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```
    Installs required libraries (Flask, ML tools, data processing libraries, etc.).

3. **Run the Flask service locally:**
    ```bash
    python app.py
    ```
    Starts the Flask server on port 5000. Test the service:
    ```bash
    curl http://localhost:5000/predict
    ```
    You should receive a JSON response indicating a sample prediction.

4. **Build and run Docker container:**
    ```bash
    docker build -t highpeaks-ml-platform:latest .
    docker run -p 5000:5000 highpeaks-ml-platform:latest
    ```
    Test again via `http://localhost:5000/predict`.

### Run Local Stack with Docker Compose (optional)

Alternatively, you can quickly launch the full local stack (Flask API, MinIO, PostgreSQL and MLflow) using Docker Compose.

Start the stack:

```bash
docker compose -f infrastructure/docker-compose.yml up -d
```

The following services will be available:

- **Flask API:** <http://localhost:5000>
- **MLflow tracking server:** <http://localhost:5001>
- **MinIO console:** <http://localhost:9001> (S3 API on port 9000)
- **PostgreSQL:** `localhost:5432`

Stop the stack with:

```bash
docker compose -f infrastructure/docker-compose.yml down
```

## Data Pipeline

Follow the sample workflow to ingest and process data and train a model:

1. Run `python data/ingestion/sample_ingestion_pipeline.py` to download the MNIST dataset. This saves `mnist.npz` under `data/raw`.
2. Run `python data/processing/process_mnist.py` to create normalized datasets. The output `mnist_processed.npz` is written to `data/processed`.
3. Run `python ml/scripts/train_mnist_model.py` to train the model and log the run to MLflow. Artifacts are stored in your configured MLflow tracking location.

## Kubernetes Deployment

Kubernetes manifests located in `infrastructure/k8s/`:

- **Namespace (`namespace.yaml`)**: Defines an isolated namespace (`highpeaks-ml`).
- **Deployment (`deployment.yaml`)**: Deploys the ML Flask service container.
- **Service (`service.yaml`)**: Internal Kubernetes ClusterIP service exposing the Flask API.
- **MLflow Tracking Server (`mlflow.yaml`)**: Deployment for MLflow experiment tracking.
- **Storage Components (`storage.yaml`)**: Manifests for deploying MinIO and PostgreSQL for data storage.


### Deploy Steps:

1. **Build and push the Docker image**
   ```bash
   docker build -t <registry>/highpeaks-ml-platform:latest .
   docker push <registry>/highpeaks-ml-platform:latest
   ```
   If using a kind cluster, load the local image instead:
   ```bash
   kind load docker-image <registry>/highpeaks-ml-platform:latest
   ```

2. **Apply Kubernetes manifests**
   ```bash
   kubectl apply -f infrastructure/k8s/
   ```

3. **Verify the services**
   ```bash
   kubectl get pods -n highpeaks-ml
   kubectl get services -n highpeaks-ml
   ```
The ML service and MLflow should now be running within the cluster.
## CI/CD Workflow

GitHub Actions (`.github/workflows/ci.yml`) executes on push or PR to:

- Install Python dependencies.
- Run linting checks (flake8).
- Execute unit and integration tests (future state).
- Validate Kubernetes manifests (`kubectl apply --dry-run=client`).
- Perform security and vulnerability scans (future state).

Upon successful merges, the container image can be pushed to a registry and deployed to Kubernetes via automated GitOps workflows or manual processes.

## Security & Future Enhancements

Upcoming iterations will enhance the platform by:

- **Securing API endpoints:** Validating incoming requests (JWT tokens, authentication via High Peaks identity service).
- **Sensitive data handling:** Securing credentials and managing secrets via Kubernetes secrets or Vault integration.
- **Resource management:** Adding Kubernetes resource constraints (`requests` and `limits`) to manage ML workloads efficiently.
- **Advanced hardware support:** Leveraging GPUs or accelerators for ML training and inference, integrating Kubernetes device plugins.
# highpeaks-ml-platform

The **High Peaks ML Platform** service is the machine learning engine of the High Peaks AI platform. It is responsible for training models and serving predictions. In a full implementation, this service might manage ML workflows, model versioning, and provide APIs for other services (and potentially the DevOps AI agent) to trigger training or retrieve prediction results. For now, we scaffold a basic web service to illustrate the component structure.

## Repository Structure

```text
highpeaks-ml-platform/
├── README.md               # Overview of the ML platform service
├── Dockerfile              # Containerization for the ML service
├── requirements.txt        # Python dependencies (e.g., Flask)
├── app.py                  # Flask application simulating ML service endpoints
├── k8s/
│   ├── deployment.yaml     # Kubernetes Deployment for ML service
│   └── service.yaml        # Kubernetes Service to expose the ML service internally
└── .github/
    └── workflows/
        └── ci.yml         # GitHub Actions workflow for CI (linting, manifest validation)
```

## Development Setup

**Prerequisites:** Python 3.x (e.g., 3.10) and pip installed on your development machine.

1. **Setup a virtual environment (optional but recommended):**  
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
   This creates and activates a virtual environment for dependencies.
2. **Install dependencies:**  
   ```bash
   pip install -r requirements.txt
   ``` 
   This will install Flask (and any other required libraries).
3. **Run the service locally:**  
   ```bash
   python app.py
   ``` 
   This starts the Flask development server on port 5000. You should see console logs indicating the server is running. Test it by sending a GET request to `http://localhost:5000/predict` (it should return a sample prediction result in JSON).
4. **Build the Docker image:** Ensure Docker is running, then build the image:  
   ```bash
   docker build -t highpeaks-ml-platform:latest .
   ``` 
   You can then run the container for local testing:  
   ```bash
   docker run -p 5000:5000 highpeaks-ml-platform:latest
   ``` 
   This maps the container's port to your local port 5000. The service should respond to `http://localhost:5000/predict` when the container is running.

## Kubernetes Deployment

Kubernetes manifests are provided in the `k8s/` directory:
- `deployment.yaml` defines a Deployment for the ML service, which by default runs a single replica of the container image (defaults to `highpeaks-ml-platform:latest`).
- `service.yaml` defines a ClusterIP Service on port 80 (routing to the container's port 5000) to allow other in-cluster services (e.g., the DevOps agent) to communicate with the ML platform.

To deploy to a Kubernetes cluster (e.g., a local Kind cluster):
1. Ensure the Docker image is built. If using Kind, load the image into the cluster:  
   ```bash
   kind load docker-image highpeaks-ml-platform:latest
   ```
2. Apply the manifests:  
   ```bash
   kubectl apply -f k8s/deployment.yaml
   kubectl apply -f k8s/service.yaml
   ``` 
   This will create the deployment and service (in the default or current namespace; consider using a dedicated namespace like `highpeaks-ml`).

## CI/CD

The GitHub Actions workflow (`.github/workflows/ci.yml`) for this repo runs on each push/PR:
- It installs the Python environment and dependencies.
- Runs basic linting (e.g., flake8 for Python code style) and validates the Kubernetes YAML manifests (using a dry-run apply).
- (In the future, this service would include unit tests for ML logic, which would also run in CI. Additionally, model quality checks or training pipeline tests might be integrated.)

Like other High Peaks services, on a successful CI and merge, this service's container image can be pushed to a registry and deployed via a GitOps or CI/CD pipeline. Security checks (such as scanning for vulnerable packages) would also be integrated as the codebase grows.

## Security & Future Enhancements

In a full implementation, the ML platform service would likely:
- Validate incoming requests (e.g., ensure the identity service's JWT tokens are provided and valid for secure endpoints).
- Possibly handle sensitive data (like dataset storage or model artifacts), so it would be configured with proper access controls and secrets management for any credentials.
- Include resource management (requests/limits in Kubernetes) to ensure ML tasks do not exhaust cluster resources.
- Leverage GPUs or specialized hardware for training/inference when available (in which case, the Kubernetes manifests would include device plugins or node selectors as needed).

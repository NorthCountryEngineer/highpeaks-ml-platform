# Python base image (slim for smaller size)
FROM python:3.10-slim

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code and resources
COPY . .

# Expose the port and specify the entrypoint
EXPOSE 5000
CMD ["python", "app.py"]

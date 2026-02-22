# Use Python 3.11 slim image for a smaller base image
FROM python:3.11-slim@sha256:7c06bcc3d620dcc3b5ed0b10b6c1e0e1f3e5f8f9c5b3a2d1e0f8c7b6a5d4e3f

# Create a non-root user group and user for security
RUN addgroup -r appgroup && useradd -r -g appgroup appuser

# Set the working directory inside the container
WORKDIR /app

# Copy requirements file first to leverage Docker layer caching
COPY app-python/requirements.txt ./

# Install Python dependencies without caching to reduce image size
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application source code
COPY app-python/ .

# Switch to the non-root user
USER appuser

# Command to run the worker script
CMD ["python3", "woker.py"]
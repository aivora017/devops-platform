# Use Python 3.12 slim image as the base for a smaller footprint
FROM python:3.12-slim

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
CMD ["python3", "worker.py"]
import logging
import os
import signal
import sys
import time
import requests

# Constants
DEFAULT_API_URL = 'http://localhost:8080'
DEFAULT_CHECK_INTERVAL = 10  # seconds
DEFAULT_STARTUP_TIMEOUT = 60  # seconds for initial health check
DEFAULT_STARTUP_RETRY_DELAY = 2  # seconds between retries

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_env_var(key: str, default: str) -> str:
    """Get environment variable with fallback to default."""
    return os.getenv(key, default)

def wait_for_api(api_url: str, timeout: int, retry_delay: int) -> bool:
    """Wait for the API to be ready by polling a health endpoint."""
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            response = requests.get(f'{api_url}/health', timeout=5)  # Assume /health endpoint
            if response.status_code == 200:
                logger.info("API is ready")
                return True
        except requests.RequestException as e:
            logger.warning(f"API not ready yet: {e}")
        time.sleep(retry_delay)
    logger.error(f"API did not become ready within {timeout} seconds")
    return False

def check_health(api_url: str) -> None:
    """Check the Go API health and log the result."""
    try:
        response = requests.get(f'{api_url}/health', timeout=10)
        if response.status_code == 200:
            try:
                data = response.json()
                logger.info(f"Health check successful: {data}")
            except ValueError:
                logger.error("Health check response is not valid JSON")
        else:
            logger.error(f"Health check failed with status code: {response.status_code}")
    except requests.RequestException as e:
        logger.error(f"Error during health check: {e}")

def main() -> None:
    """Main worker loop."""
    api_url = get_env_var('GO_API_URL', DEFAULT_API_URL)
    check_interval = int(get_env_var('CHECK_INTERVAL', str(DEFAULT_CHECK_INTERVAL)))
    startup_timeout = int(get_env_var('STARTUP_TIMEOUT', str(DEFAULT_STARTUP_TIMEOUT)))
    startup_retry_delay = int(get_env_var('STARTUP_RETRY_DELAY', str(DEFAULT_STARTUP_RETRY_DELAY)))

    # Validate API URL
    if not api_url.startswith(('http://', 'https://')):
        logger.error("Invalid API URL format (must start with http:// or https://)")
        sys.exit(1)

    # Wait for API to be ready
    if not wait_for_api(api_url, startup_timeout, startup_retry_delay):
        sys.exit(1)

    logger.info("Python worker started")

    # Signal handler for graceful shutdown
    def signal_handler(signum, frame):
        logger.info("Received signal, shutting down gracefully")
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Main loop
    while True:
        check_health(api_url)
        time.sleep(check_interval)

if __name__ == "__main__":
    main()
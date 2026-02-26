import logging
import os
import time
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# TODO: move these to env vars later
API_URL = os.getenv('GO_API_URL', 'http://localhost:8080')
CHECK_INTERVAL = 10

def wait_for_api(url, timeout=60):
    start = time.time()
    while time.time() - start < timeout:
        try:
            r = requests.get(f'{url}/health', timeout=5)
            if r.status_code == 200:
                logger.info("API is up!")
                return True
        except Exception as e:
            logger.info(f"Waiting for API... ({e})")
        time.sleep(2)
    logger.error("API startup timeout")
    return False

def main():
    if not wait_for_api(API_URL):
        exit(1)

    logger.info(f"Python worker started, checking {API_URL} every {CHECK_INTERVAL}s")
    
    while True:
        try:
            r = requests.get(f'{API_URL}/health')
            if r.status_code == 200:
                logger.info(f"OK: {r.json()}")
        except Exception as e:
            logger.error(f"Health check failed: {e}")
        
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()
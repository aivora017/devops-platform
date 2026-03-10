import logging
import os
import time
import requests
from prometheus_client import Counter, Gauge, start_http_server

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

API_URL = os.getenv('GO_API_URL', 'http://localhost:8080')
CHECK_INTERVAL = 10

WORKER_CHECKS_TOTAL = Counter(
    'worker_health_checks_total',
    'Total health check attempts by the python worker',
    ['result']
)
WORKER_CHECK_DURATION_SECONDS = Gauge(
    'worker_health_check_duration_seconds',
    'Duration of the latest health check in seconds'
)
WORKER_LAST_SUCCESS_TIMESTAMP = Gauge(
    'worker_last_success_timestamp_seconds',
    'Unix timestamp of the latest successful health check'
)

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
    metrics_port = int(os.getenv('METRICS_PORT', '8000'))
    start_http_server(metrics_port)
    logger.info(f"Prometheus metrics exposed on port {metrics_port}")

    if not wait_for_api(API_URL):
        exit(1)

    logger.info(f"Python worker started, checking {API_URL} every {CHECK_INTERVAL}s")
    
    while True:
        start = time.time()
        try:
            r = requests.get(f'{API_URL}/health')
            WORKER_CHECK_DURATION_SECONDS.set(time.time() - start)
            if r.status_code == 200:
                WORKER_CHECKS_TOTAL.labels(result='success').inc()
                WORKER_LAST_SUCCESS_TIMESTAMP.set(time.time())
                logger.info(f"OK: {r.json()}")
            else:
                WORKER_CHECKS_TOTAL.labels(result='non_200').inc()
                logger.warning(f"Non-200 health response: {r.status_code}")
        except Exception as e:
            WORKER_CHECK_DURATION_SECONDS.set(time.time() - start)
            WORKER_CHECKS_TOTAL.labels(result='error').inc()
            logger.error(f"Health check failed: {e}")
        
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()
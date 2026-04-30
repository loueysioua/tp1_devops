import os
import socket
from flask import Flask
import redis
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)

# Métriques Prometheus
REQUEST_COUNT = Counter(
    'app_requests_total',
    'Nombre total de requêtes',
    ['method', 'endpoint', 'status']
)
REQUEST_LATENCY = Histogram(
    'app_request_latency_seconds',
    'Latence des requêtes en secondes',
    ['endpoint']
)

# Connexion Redis
cache = redis.Redis(host='db-service', port=6379)

@app.route('/')
def hello():
    start = time.time()
    try:
        count = cache.incr('hits')
        status = '200'
    except redis.exceptions.ConnectionError:
        REQUEST_COUNT.labels(method='GET', endpoint='/', status='500').inc()
        return "Erreur : Impossible de se connecter à Redis (db-service).", 500

    container_id = socket.gethostname()
    REQUEST_COUNT.labels(method='GET', endpoint='/', status='200').inc()
    REQUEST_LATENCY.labels(endpoint='/').observe(time.time() - start)
    return f"Bonjour ! Cette page a été vue {count} fois. Je suis le conteneur {container_id}"

@app.route('/metrics')
def metrics():
    """Endpoint Prometheus — scrapé automatiquement via les annotations du pod."""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/health')
def health():
    """Liveness / Readiness probe."""
    return {"status": "ok"}, 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

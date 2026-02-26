import os
import socket
from flask import Flask
import redis

app = Flask(__name__)

# Connexion au serveur Redis nommé 'db-service'
# Le port 6379 est le port par défaut de Redis
cache = redis.Redis(host='db-service', port=6379)

@app.route('/')
def hello():
    try:
        # Incrémente la clé 'hits' à chaque visite
        count = cache.incr('hits')
    except redis.exceptions.ConnectionError:
        return "Erreur : Impossible de se connecter à Redis (db-service)."

    # Récupère l'ID du conteneur (qui correspond au hostname)
    container_id = socket.gethostname()

    return f"Bonjour ! Cette page a été vue {count} fois. Je suis le conteneur {container_id}"

if __name__ == "__main__":
    # Écoute sur toutes les interfaces réseau (nécessaire dans un conteneur)
    app.run(host="0.0.0.0", port=5000)
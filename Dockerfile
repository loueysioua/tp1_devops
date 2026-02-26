FROM python:3.11-alpine

# 2. Création d'un utilisateur non-root pour la sécurité
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 3. Définition du répertoire de travail
WORKDIR /app

# 4. Optimisation du cache Docker : on copie D'ABORD les dépendances
COPY requirements.txt .

# 5. Installation des dépendances
# --no-cache-dir évite de stocker les fichiers temporaires de pip (réduit la taille de l'image)
RUN pip install --no-cache-dir -r requirements.txt

# 6. Copie du reste du code source
COPY app.py .

# 7. Changement de propriétaire des fichiers pour notre utilisateur non-root
RUN chown -R appuser:appgroup /app

# 8. Bascule sur l'utilisateur non-root
USER appuser

# 9. Exposition du port de l'application Flask
EXPOSE 5000

# 10. Commande de démarrage
CMD ["python", "app.py"]
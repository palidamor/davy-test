# Use a slim, official base image to keep the final image small and reduce
# attack surface (fewer packages = fewer vulnerabilities).
FROM python:3.12-slim

# Set the working directory inside the container.
WORKDIR /app

# Copy only the dependency file first so Docker can cache this layer.
# Dependencies only get reinstalled when requirements.txt actually changes,
# not on every code edit — speeds up rebuilds significantly.
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Now copy the rest of the application source.
COPY . .

# Create a non-root user and run as that user. Cloud Run (and containers in
# general) should never run application code as root — limits the damage if
# the app is ever compromised.
# Docs: https://docs.cloud.google.com/run/docs/tips/general#container-security
RUN useradd -m appuser
USER appuser

# Cloud Run injects the PORT environment variable at runtime and routes
# traffic to whatever port your container listens on (8080 by default).
# Your app must read this variable rather than hardcoding a port.
# Docs: https://cloud.google.com/run/docs/container-contract#port
ENV PORT=8080
EXPOSE 8080

# Use gunicorn instead of Flask's built-in dev server — the dev server is
# single-threaded and explicitly not meant for production traffic.
#   -b 0.0.0.0:8080   bind to all interfaces on the Cloud Run port
#   -w 2              2 worker processes; tune based on your CPU allocation
#   --timeout 0       disable gunicorn's own worker timeout and let Cloud
#                     Run's request timeout setting govern instead
# Docs: https://cloud.google.com/run/docs/tips/general#optimize_concurrency
CMD ["gunicorn", "-b", "0.0.0.0:8080", "-w", "2", "--timeout", "0", "main:app"]

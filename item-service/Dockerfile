# Base Python image
FROM python:3.10-slim

# Create app directory
WORKDIR /usr/src/app

# Install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source
COPY app.py .

# Expose service port
EXPOSE 3002

# Run the service
CMD [ "python", "-u", "app.py" ]
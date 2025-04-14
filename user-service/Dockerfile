# Base Node image
FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Copy package.json and install dependencies
COPY package.json .
RUN npm install --production

# Copy source
COPY index.js .

# Expose service port
EXPOSE 3001

# Run the service
CMD [ "npm", "start" ]
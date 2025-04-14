# Base Node image for building
FROM node:18-alpine as build

WORKDIR /usr/src/app
COPY package.json .
RUN npm install
COPY . .
RUN npm run build

# Production image for serving content
FROM nginx:alpine
COPY --from=build /usr/src/app/build /usr/share/nginx/html

# Expose default Nginx port
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
# Stage 1: Build the React application
FROM node:18-alpine AS build

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json (or yarn.lock)
COPY package.json ./
COPY package-lock.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application source code
COPY . .

# Build the application for production
RUN npm run build

# Stage 2: Serve the static files using Nginx
FROM nginx:1.25-alpine AS production

# Copy the build output from the build stage to Nginx's web server directory
COPY --from=build /app/build /usr/share/nginx/html

# Optional: Add a custom Nginx configuration if needed for client-side routing.
# Create a file named nginx.conf in the root (or a conf.d folder)
# and copy it into the Nginx configuration directory.
# For a typical CRA, Nginx's default config might work, but for client-side routing,
# you often need to tell Nginx to fall back to index.html.
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Example nginx.conf content:
# server {
#   listen 80;
#   server_name localhost;
#
#   location / {
#     root   /usr/share/nginx/html;
#     index  index.html index.htm;
#     try_files $uri $uri/ /index.html; # Important for client-side routing
#   }
#
#   # Optional: Add other locations, error pages, etc.
#   error_page   500 502 503 504  /50x.html;
#   location = /50x.html {
#     root   /usr/share/nginx/html;
#   }
# }

# Expose port 80
EXPOSE 80

# Start Nginx when the container launches
CMD ["nginx", "-g", "daemon off;"]

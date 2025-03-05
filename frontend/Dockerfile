# Step 1: Build the React app
FROM node:14-alpine AS build

# Set the working directory inside the container
WORKDIR /app

# Install the dependencies
COPY package.json package-lock.json ./

RUN npm install

# Copy the rest of the React app
COPY . .

# Build the React app
RUN npm run build && rm -rf /app/node_modules

# Step 2: Serve the built app using a static server (Nginx)
FROM nginx:alpine

# Copy the built React app from the build stage to Nginx's public folder
COPY --from=build /app/build /usr/share/nginx/html

# Expose port 80 for Nginx
EXPOSE 80

# Start Nginx server to serve the app
CMD ["nginx", "-g", "daemon off;"]

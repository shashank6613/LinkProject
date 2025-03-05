# Step 1: Use the official Node.js image
FROM node:14-alpine AS build

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json to the container
COPY package.json package-lock.json ./

# Install backend dependencies
RUN npm install

# Copy the rest of the backend code
COPY . .

# Expose the backend port (5000)
EXPOSE 5000

# Start the backend server
CMD ["node", "index.js"]

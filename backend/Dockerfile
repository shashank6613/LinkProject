# Step 1: Build dependencies
FROM node:16-alpine AS build

# Set working directory
WORKDIR /app

# Copy dependency files first (better layer caching)
COPY package.json package-lock.json ./

# Install exact dependencies (respect package-lock.json)
RUN npm ci --only=production

# Copy the rest of the backend code
COPY . .

# Step 2: Run backend
FROM node:16-alpine

WORKDIR /app

# Copy only the necessary files from build stage
COPY --from=build /app /app

# Expose the backend port
EXPOSE 5000

# Start the backend
CMD ["npm", "start"]


FROM node:20-slim
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Copy application code
COPY . .

ENV PORT=8080
EXPOSE 8080
CMD ["node", "server.js"]

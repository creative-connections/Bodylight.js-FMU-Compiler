# Start from the latest Emscripten SDK image
FROM emscripten/emsdk:latest

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the bash script into the container
COPY . .
# Make the script executable
#RUN chmod +x worker.sh

# Install a simple HTTP server (e.g., Node.js http-server)
#RUN apt-get update && apt-get install -y nodejs npm
#RUN npm install -g http-server

# Copy your web files (HTML, JS, etc.) into the container
# Replace 'your_web_files/' with your actual web files directory
COPY index.html ./public

# Expose the port the HTTP server will use
EXPOSE 8080

# Run the HTTP server and the bash script
# The HTTP server serves files from the 'public' directory
CMD ["bash"]

FROM apiaryio/emcc
WORKDIR /work
ADD ./compiler /compiler

RUN apt-get install -y git

# Run app.py when the container launches
#CMD ["python", "app.py"]

FROM apiaryio/emcc
WORKDIR /work

RUN \
  apt-get update; \
  apt-get install -y \
    build-essential \
    clang \
    libxml2-utils \
    zip \
    inotify-tools \
    file \
    unzip \
    pkg-config \
    gcc;
    
ADD ./compiler /work

CMD ["bash", "worker.sh"]

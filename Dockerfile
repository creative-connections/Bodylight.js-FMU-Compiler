FROM apiaryio/emcc
WORKDIR /work
ADD ./compiler /work

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

CMD ["bash", "worker.sh"]

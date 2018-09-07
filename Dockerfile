FROM apiaryio/emcc
WORKDIR /work
ADD ./compiler /work

RUN apt-get install -y libxml2-utils zip inotify-tools file unzip

CMD ["bash", "worker.sh"]

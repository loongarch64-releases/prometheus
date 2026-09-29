FROM lcr.loongnix.cn/library/debian:unstable

RUN apt update && apt install -y git \
    golang \
    make \
    libseccomp-dev \
    wget \
    build-essential \
    curl \
    nodejs \
    npm

RUN npm install -g pnpm@11.27.1

ENV PROMETHEUS_VERSION=''

CMD ["sh", "-c","/workspace/process_version.sh $PROMETHEUS_VERSION"]

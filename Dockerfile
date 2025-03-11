FROM python:3.9.16-buster

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends gfortran libpcre2-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN wget http://cran.rstudio.com/src/base/R-4/R-4.2.0.tar.gz && \
    tar -xvf R-4.2.0.tar.gz && \
    cd R-4.2.0 && \
    ./configure --prefix=/usr/local --enable-R-shlib=yes && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf R-4.2.0*

RUN echo "/usr/local/lib/R/lib" > /etc/ld.so.conf.d/r-libs.conf && \
    ldconfig

CMD ["/bin/bash"]

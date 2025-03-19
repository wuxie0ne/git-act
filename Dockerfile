FROM amazoncorretto:8u422

RUN yum update -y && \
    yum install -y tar rsync && \
    yum clean all


ENV JAR_NAME=app.jar
ENV JAVA_ARG=-Djava.security.egd=file:/dev/./urandom -Duser.timezone=GMT+08

ENV TZ=Asia/Shanghai

WORKDIR /jar

ENTRYPOINT ["/bin/sh", "-c", "java $JAVA_ARG -jar $JAR_NAME"]

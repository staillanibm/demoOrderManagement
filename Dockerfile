FROM ibmwebmethods.azurecr.io/webmethods-microservicesruntime:11.1.0.9 AS builder

ARG WPM_TOKEN
#ARG GIT_TOKEN

RUN /opt/softwareag/wpm/bin/wpm.sh install -ws https://packages.webmethods.io -wr licensed -j $WPM_TOKEN -d /opt/softwareag/IntegrationServer WmJDBCAdapter:latest
RUN curl -o /opt/softwareag/IntegrationServer/packages/WmJDBCAdapter/code/jars/postgresql-42.7.4.jar "https://jdbc.postgresql.org/download/postgresql-42.7.4.jar"

ADD --chown=1724:0 . /opt/softwareag/IntegrationServer/packages/demoOrderManagement

USER 0
RUN chgrp -R 0 /opt/softwareag && chmod -R g=u /opt/softwareag


FROM ibmwebmethods.azurecr.io/webmethods-microservicesruntime:11.1.0.9

USER 1724

COPY --from=builder /opt/softwareag/IntegrationServer /opt/softwareag/IntegrationServer

FROM ibmwebmethods.azurecr.io/webmethods-microservicesruntime:11.1.0.9 AS builder

ARG WPM_TOKEN
#ARG GIT_TOKEN

# The JDBC adapter package
RUN /opt/softwareag/wpm/bin/wpm.sh install -ws https://packages.webmethods.io -wr licensed -j $WPM_TOKEN -d /opt/softwareag/IntegrationServer WmJDBCAdapter:latest

# The PostgreSQL JDBC driver, for use with the JDBC adapter.
ADD --chown=1724:0 dependencies/drivers/postgresql-42.7.4.jar /opt/softwareag/IntegrationServer/packages/WmJDBCAdapter/code/jars/postgresql-42.7.4.jar

# The WmMonitor package
ADD --chown=1724:0 dependencies/packages/WmMonitor /opt/softwareag/IntegrationServer/packages/WmMonitor

# Datadirect Connect JDBC driver, for use with JDBC pools (needed by the WmMonitor package)
ADD --chown=1724:0 dependencies/drivers/dd-cjdbc.jar /opt/softwareag/common/lib/ext/dd-cjdbc.jar

# The demo Order Management package
ADD --chown=1724:0 . /opt/softwareag/IntegrationServer/packages/demoOrderManagement


USER 0
RUN chgrp -R 0 /opt/softwareag && chmod -R g=u /opt/softwareag


FROM ibmwebmethods.azurecr.io/webmethods-microservicesruntime:11.1.0.9

USER 1724

COPY --from=builder /opt/softwareag /opt/softwareag
